//
//  BufferPool.m
//  Unity-iPhone
//
//  Created by Alexander Degtyarev on 3/18/14.
//
//
#import "BufferPool.h"

@interface BufferPool ()
- (void)returnToPool:(NSNumber *)item;
@end

@implementation BufferPool
const int bufferPoolSize = 40;

- (id)initBufferPoolWithSize:(uint)poolSize{
    self = [super init];
    if (self)
    {
        bufferPeek = poolSize;
        freeBuffers = [[NSMutableArray alloc] initWithCapacity:bufferPoolSize];
        boundBuffers = [[NSMutableArray alloc] initWithCapacity:bufferPeek];
        referenceCounter = [[NSMutableArray alloc] initWithCapacity:bufferPeek];
        elementsCount = [[NSMutableArray alloc] initWithCapacity:bufferPeek];

        GLuint* poolItemsName = malloc(sizeof(GLuint)*bufferPoolSize);
        glGenBuffers(bufferPoolSize,poolItemsName);

        for(int i = 0; i<bufferPoolSize; i++){
            [freeBuffers addObject:@(poolItemsName[i])];
        }

        for(int i = 0; i<bufferPeek; i++){
            [boundBuffers addObject:@0];
            [referenceCounter addObject:@0];
            [elementsCount addObject:@0];
        }

        int err = glGetError();
        if(err != 0){
            printf("GLERRORS %x",err);
        }
        free(poolItemsName);
    }
    return self;
}

- (id)initTexturePoolWithSize:(uint)poolSize{
    self = [super init];
    if (self)
    {
        bufferPeek = poolSize;
        freeBuffers = [[NSMutableArray alloc] initWithCapacity:bufferPoolSize];
        boundBuffers = [[NSMutableArray alloc] initWithCapacity:bufferPeek];
        referenceCounter = [[NSMutableArray alloc] initWithCapacity:bufferPeek];
        elementsCount = [[NSMutableArray alloc] initWithCapacity:bufferPeek];

        GLuint* poolItemsName = malloc(sizeof(GLuint)*bufferPoolSize);
        glGenTextures(bufferPoolSize, poolItemsName);

        for(int i = 0; i<bufferPoolSize; i++){
            [freeBuffers addObject:@(poolItemsName[i])];
        }

        for(int i = 0; i<bufferPeek; i++){
            [boundBuffers addObject:@0];
            [referenceCounter addObject:@0];
            [elementsCount addObject:@0];
        }

        int err = glGetError();
        if(err != 0){
            printf("GLERRORS %x",err);
        }
        free(poolItemsName);
    }
    return self;
}

-(GLuint) getFreeBufferObject{
    GLuint result = [freeBuffers.lastObject unsignedIntValue];
    [freeBuffers removeLastObject];
    return result;
}

-(void) returnToPool:(NSNumber*) item{
    [freeBuffers addObject:item];
}

- (void)unbindPoolItemWithDataId:(uint)dataId {
    if([referenceCounter[dataId] unsignedIntValue] > 0){
        referenceCounter[dataId] = @([referenceCounter[dataId] unsignedIntValue] - 1);
    }
    if([referenceCounter[dataId] unsignedIntValue] == 0){
        [self returnToPool:boundBuffers[dataId]];
        referenceCounter[dataId] = @0;
        boundBuffers[dataId] = @0;
    }
}

-(void)retainPoolItemForDataId: (uint)dataId {
    referenceCounter[dataId] = @([referenceCounter[dataId] unsignedIntValue] + 1);
}

- (void)bindPoolItem:(GLuint)item forDataId:(uint)dataId withElementCount:(uint)count {
    [self retainPoolItemForDataId:dataId];
    if(![self hasPoolItemBoundToDataId:dataId]){
        elementsCount[dataId] = @(count);
        boundBuffers[dataId] = @(item);
    }
}

- (GLuint)getPoolItemBoundToDataId:(uint)dataId {
    return [boundBuffers[dataId] unsignedIntValue];
}

- (Boolean)hasPoolItemBoundToDataId:(uint)dataId {
    if(dataId>bufferPeek || dataId < 1)
    {
        printf("ERROR data id is corrupt , %i",dataId);
        return false;
    }else{
        return [boundBuffers[dataId] unsignedIntValue] != 0;
    }
}

- (int)getElementsCountBoundToDataId:(uint)dataId {
    return [elementsCount[dataId] unsignedIntValue];
}

- (int)getReferenceCount:(uint)id {
    return [referenceCounter[id] unsignedIntValue];
}

- (void)dealloc {
    [freeBuffers release];
    [boundBuffers release];
    [elementsCount release];
    [referenceCounter release];
    [super dealloc];
}
@end


