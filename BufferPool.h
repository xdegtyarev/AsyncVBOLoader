//
//  BufferPool.h
//  Unity-iPhone
//
//  Created by Alexander Degtyarev on 3/18/14.
//
//

#import "OpenGLES/EAGL.h"
#import "OpenGLES/ES2/gl.h"

@interface BufferPool : NSObject{
    NSUInteger bufferPeek;
    NSMutableArray* freeBuffers;
    NSMutableArray* boundBuffers;
    NSMutableArray* elementsCount;
    NSMutableArray* referenceCounter;
}

- (id)initBufferPoolWithSize:(uint)poolSize;
- (id)initTexturePoolWithSize:(uint)poolSize;
- (GLuint)getFreeBufferObject;
- (void)unbindPoolItemWithDataId:(uint)dataId;
- (void)retainPoolItemForDataId:(uint)dataId;

- (void)bindPoolItem:(GLuint)item forDataId:(uint)dataId withElementCount:(uint)count;
- (GLuint)getPoolItemBoundToDataId:(uint)dataId;
- (Boolean)hasPoolItemBoundToDataId:(uint)dataId;

- (int)getElementsCountBoundToDataId:(uint)dataId;

- (int)getReferenceCount:(uint)id;
@end
