//
//  BackgroundVBOLoader.m
//  BackgroundVBOLoader
//
//  Created by Alexander Degtyarev on 3/12/14.
//  Copyright (c) 2014 Alexander Degtyarev. All rights reserved.
//

#import "BackgroundVBOLoader.h"
//////////////////////////////////////API TO UNITY/////////////////////////////////////////////
//called once to init BufferPools, count meshes
void _backgroundVBOLoaderInit(uint indexDataCount,uint vertexDataCount, uint textureDataCount)
{
    [[BackgroundVBOLoader sharedLoader] initializeWithIndexDataCount:indexDataCount vertexDataCount:vertexDataCount textureDataCount:textureDataCount];
}
//called multiple times in rendering update
void _backgroundVBOLoaderBeginRendering(uint indexDataId,float o2w[],float mv[], float lightmapST[])
{
    [[BackgroundVBOLoader sharedLoader] renderWithIBOIndex:indexDataId model:o2w view:mv lightmapTilingOffset: lightmapST];
}
//called each time Unity decides to enqueue backgroundVBO creation;
void _backgroundVBOLoaderPreloadVBOInBackground(uint indexData, uint vertexData, uint lightmapData)
{
    struct DrawCallData data;
    data.indexDataId = indexData;
    data.vertexDataId = vertexData;
    data.lightmapDataId = lightmapData;
    [[BackgroundVBOLoader sharedLoader] enqueueBackgroundDataLoad:data];
}
//called each time Unity decides that we no longer need filled VBO;
void _backgroundVBOLoaderUnloadVBO(uint indexDataId)
{
    [[BackgroundVBOLoader sharedLoader] unloadIBO:indexDataId];
}
///////////////////////////////////////////END/////////////////////////////////////////////


@interface BackgroundVBOLoader ()
- (void)enqueue:(uint)meshId;
- (uint)dequeue;
@end

@implementation BackgroundVBOLoader{}
static BackgroundVBOLoader *__sharedLoader = nil;

+ (instancetype)sharedLoader
{
    if(__sharedLoader == NULL){
        __sharedLoader = [[BackgroundVBOLoader alloc]init];
    }
    return __sharedLoader;
}

- (void)initializeWithIndexDataCount:(uint)indexDataCount vertexDataCount:(uint)vertexDataCount textureDataCount:(uint)textureDataCount
{
    unityContext = [EAGLContext currentContext];
    [unityContext retain];
    backgroundContext = [[EAGLContext alloc] initWithAPI:[unityContext API] sharegroup:[unityContext sharegroup]];
    drawCalls = malloc(sizeof(struct DrawCallData) * indexDataCount);
    memset(drawCalls, 0, sizeof(struct DrawCallData) * indexDataCount);
    [backgroundContext retain];
    indexBufferPool = [[BufferPool alloc] initBufferPoolWithSize:indexDataCount];
    vertexBufferPool = [[BufferPool alloc] initBufferPoolWithSize:vertexDataCount];
    texturePool = [[BufferPool alloc] initTexturePoolWithSize:textureDataCount];
    queue = [[NSMutableArray alloc] init];
    queueLock = [NSLock new];

    if(backgroundContext!=NULL && unityContext!=NULL){
        printf("Contexts catched");
    }
    printf("Inited");
}

- (void) dealloc{
    [unityContext release];
    [backgroundContext release];
    [queue release];
    [queueLock release];
    [indexBufferPool release];
    [vertexBufferPool release];
    [texturePool release];
    free(drawCalls);
    [super dealloc];
}

- (void)renderWithIBOIndex:(uint)indexDataId model:(float [16])o2w view:(float [16])mv lightmapTilingOffset:(float [4])offset {
    if(unityContext != NULL){
        struct DrawCallData data = drawCalls[indexDataId];

        if([vertexBufferPool hasPoolItemBoundToDataId:data.vertexDataId]){
            glBindBuffer(GL_ARRAY_BUFFER, [vertexBufferPool getPoolItemBoundToDataId:data.vertexDataId]);
        }else{
            printf("No bound vbo refCount %i",[vertexBufferPool getReferenceCount: data.vertexDataId]);
            printf("No bound vertex buffer yet %i",data.vertexDataId);
            return;
        }

        if([indexBufferPool hasPoolItemBoundToDataId:data.indexDataId]){
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, [indexBufferPool getPoolItemBoundToDataId:data.indexDataId]);
        }else{
            printf("No bound ibo refCount %i",[vertexBufferPool getReferenceCount: data.indexDataId]);
            printf("No bound index buffer yet %i",data.indexDataId);
            return;
        }

        if(data.lightmapDataId!=0){
            if([texturePool hasPoolItemBoundToDataId:data.lightmapDataId]){
                glActiveTexture(GL_TEXTURE0);

                glBindTexture(GL_TEXTURE_2D, [texturePool getPoolItemBoundToDataId:data.lightmapDataId]);
                int err = glGetError();
                if(err!=0){
                    printf("GLERRORS at binding tex %x ",err);
                }
            }else{
                return;
            }
        }

        int program;
        int attribLocation = 0;

        glGetIntegerv(GL_CURRENT_PROGRAM, &program);
        if(program>-1){
            attribLocation = glGetAttribLocation(program, "_glesVertex");
            if(attribLocation != -1){
                glEnableVertexAttribArray(attribLocation);
                glVertexAttribPointer(attribLocation, 3, GL_FLOAT, GL_FALSE, sizeof(struct VertexData),(void *)offsetof(struct VertexData,position));
            }

            attribLocation = glGetAttribLocation(program, "_glesNormal");
            if(attribLocation != -1){
            glEnableVertexAttribArray(attribLocation);
            glVertexAttribPointer(attribLocation, 3, GL_FLOAT, GL_FALSE, sizeof(struct VertexData),(void *)offsetof(struct VertexData,normal));
            }

            attribLocation = glGetAttribLocation(program, "_glesMultiTexCoord0");
            if(attribLocation != -1){
            glEnableVertexAttribArray(attribLocation);
            glVertexAttribPointer(attribLocation, 2, GL_FLOAT, GL_FALSE, sizeof(struct VertexData),(void *)offsetof(struct VertexData,uvs));
            }

            if(data.lightmapDataId!=0){
                attribLocation = glGetAttribLocation(program, "_glesMultiTexCoord1");
                if(attribLocation != -1){
                    glEnableVertexAttribArray(attribLocation);
                    glVertexAttribPointer(attribLocation, 2, GL_FLOAT, GL_FALSE, sizeof(struct VertexData),(void *)offsetof(struct VertexData,uvs2));
                }

                int uniformLoc = glGetUniformLocation(program, "_Lightmap");
                if(uniformLoc != -1){
                    glUniform1i(uniformLoc,0);
                }
                glUniform4f(glGetUniformLocation(program, "_Lightmap_ST"), offset[0], offset[1], offset[2], offset[3]);
            }

            glUniformMatrix4fv(glGetUniformLocation(program, "_Object2World"), 1, GL_FALSE, o2w);
            glUniformMatrix4fv(glGetUniformLocation(program, "glstate_matrix_modelview0"), 1, GL_FALSE, mv);

            if([indexBufferPool hasPoolItemBoundToDataId:data.indexDataId] && glGetError() == GL_NO_ERROR){
                glDrawElements(GL_TRIANGLES, [indexBufferPool getElementsCountBoundToDataId:data.indexDataId], GL_UNSIGNED_SHORT, 0);
            }else{
                int err = glGetError();
                if(err!=0){
                    printf("GLERRORS at Rendering %x ",err);
                }
            }
        }
    }
}

- (void) enqueueBackgroundDataLoad:(struct DrawCallData) data{
    drawCalls[data.indexDataId] = data;
    [self enqueue:data.indexDataId];
}

- (void) enqueue:(uint) data{
    [queueLock lock];
    if(data == 0){
        @throw [NSException exceptionWithName:@"Enquing 0" reason:@"?" userInfo:nil];
    }
    [queue addObject:@(data)];
    if(queue.count == 1){
        [self performSelectorInBackground:@selector(loadDataInBackground:) withObject:backgroundContext];
    }
    [queueLock unlock];
}

- (uint) dequeue{
    uint result = 0;
    [queueLock lock];
    if(queue.count > 0){
        result = [[queue firstObject] unsignedIntValue];
        [queue removeObjectAtIndex:0];
    }
    [queueLock unlock];
    return result;
}

- (void)loadDataInBackground: (EAGLContext*) context {
    @autoreleasepool {
        [context retain];
        [EAGLContext setCurrentContext:context];
        while(queue.count>0){
            uint res = [self dequeue];
            struct DrawCallData drawCallData;

            if(res > 0){
                drawCallData = drawCalls[res];
                [queueLock lock];
            }else{
                continue;
            }

            if(drawCallData.indexDataId>0){
                if([indexBufferPool hasPoolItemBoundToDataId:drawCallData.indexDataId]){
                    [indexBufferPool retainPoolItemForDataId:drawCallData.indexDataId];
                }else{
                    GLuint iboId = [indexBufferPool getFreeBufferObject];
                    NSData* data = [self readBinaryMeshDataOf:drawCallData.indexDataId withExtension:@".i"];
                    [data retain];
                    void* buffer = malloc(data.length);
                    [data getBytes:buffer];
                    uint elementCount = data.length/ sizeof(GLushort);
                    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, iboId);
                    glBufferData(GL_ELEMENT_ARRAY_BUFFER, data.length, buffer, GL_STATIC_DRAW);
                    [indexBufferPool bindPoolItem:iboId forDataId:drawCallData.indexDataId withElementCount:elementCount];
                    [data release];
                    free(buffer);
                }
            }

            if(drawCallData.vertexDataId>0){
                if([vertexBufferPool hasPoolItemBoundToDataId:drawCallData.vertexDataId]){
                    [vertexBufferPool retainPoolItemForDataId:drawCallData.vertexDataId];
                }else{

                    GLuint vboId = [vertexBufferPool getFreeBufferObject];
                    NSData* data = [self readBinaryMeshDataOf:drawCallData.vertexDataId withExtension:@".v"];
                    [data retain];

                    void* buffer = malloc(data.length);
                    [data getBytes:buffer];
                    uint elementCount = data.length/ sizeof(struct VertexData);

                    glBindBuffer(GL_ARRAY_BUFFER, vboId);
                    glBufferData(GL_ARRAY_BUFFER, data.length, buffer, GL_STATIC_DRAW);
                    [vertexBufferPool bindPoolItem:vboId forDataId:drawCallData.vertexDataId withElementCount:elementCount];
                    [data release];
                    free(buffer);
                }
            }

            if(drawCallData.lightmapDataId>0){
                if([texturePool hasPoolItemBoundToDataId:drawCallData.lightmapDataId]){
                    [texturePool retainPoolItemForDataId:drawCallData.lightmapDataId];
                }else{

                    GLuint texId = [texturePool getFreeBufferObject];
                    NSData* data = [self readBinaryMeshDataOf:drawCallData.lightmapDataId withExtension:@".t"];
                    [data retain];

                    void* buffer = malloc(data.length);
                    [data getBytes:buffer];
                    uint elementCount = data.length / sizeof(GLubyte) / 3;    //RGB - no alpha channel

                    glBindTexture(GL_TEXTURE_2D, texId);
                    uint texSize = (uint) sqrt(elementCount);
                    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, texSize ,  texSize, 0, GL_RGB, GL_UNSIGNED_BYTE, buffer);
                    glGenerateMipmap(GL_TEXTURE_2D);
                    [texturePool bindPoolItem:texId forDataId:drawCallData.lightmapDataId withElementCount:elementCount];
                    [data release];
                    free(buffer);
                }
            }

            int err = glGetError();
            if(err != 0){
                printf("GLERRORS at Loading %x",err);
            }
            glFlush();
            [queueLock unlock];
        }
        [context release];
    }
}



- (NSData*)readBinaryMeshDataOf: (uint) dataId withExtension: (NSString*)dataType{
    NSString* dataPath = [[[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/Data/Raw"] stringByAppendingPathComponent:@(dataId).description] stringByAppendingString:dataType];
    return [NSData dataWithContentsOfFile:dataPath];
}

- (void)unloadIBO:(uint)indexDataId {
    struct DrawCallData drawcall = drawCalls[indexDataId];
    [indexBufferPool unbindPoolItemWithDataId:drawcall.indexDataId];
    [vertexBufferPool unbindPoolItemWithDataId:drawcall.vertexDataId];
    [texturePool unbindPoolItemWithDataId:drawcall.lightmapDataId];
}
@end
