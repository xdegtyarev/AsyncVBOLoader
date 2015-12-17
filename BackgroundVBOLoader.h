//
//  BackgroundVBOLoader.h
//  BackgroundVBOLoader
//
//  Created by Alexander Degtyarev on 3/12/14.
//  Copyright (c) 2014 Alexander Degtyarev. All rights reserved.
//
#import "BufferPool.h"
#import <OpenGLES/EAGL.h>

struct VertexData{
    float position[3];
    float normal[3];
    float uvs[2];
    float uvs2[2];
};

struct DrawCallData{
    uint indexDataId;
    uint vertexDataId;
    uint lightmapDataId;
};

@interface BackgroundVBOLoader : NSObject {
    EAGLContext* unityContext;
    EAGLContext* backgroundContext;
    BufferPool* indexBufferPool;
    BufferPool* vertexBufferPool;
    struct DrawCallData* drawCalls;
    BufferPool* texturePool;
    NSMutableArray* queue;
    NSLock* queueLock;
}

+ (instancetype) sharedLoader;
- (void)initializeWithIndexDataCount:(uint)indexDataCount vertexDataCount: (uint) vertexDataCount textureDataCount: (uint)textureDataCount;
- (void)renderWithIBOIndex:(uint)indexDataId model:(float [16])o2w view:(float [16])mv lightmapTilingOffset:(float [])offset;
- (void)enqueueBackgroundDataLoad:(struct DrawCallData)data;
- (NSData *)readBinaryMeshDataOf:(uint)dataId withExtension:(NSString *)dataType;
- (void)unloadIBO:(uint)indexDataId;

@end
