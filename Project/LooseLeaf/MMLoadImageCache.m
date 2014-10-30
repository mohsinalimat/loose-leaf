//
//  MMLoadImageCache.m
//  LooseLeaf
//
//  Created by Adam Wulf on 10/9/13.
//  Copyright (c) 2013 Milestone Made, LLC. All rights reserved.
//

#import "MMLoadImageCache.h"
#import "UIImage+Memory.h"
#import "Constants.h"

// TODO: possibly use this tutorial for threadsafe cache
// https://mikeash.com/pyblog/friday-qa-2011-10-14-whats-new-in-gcd.html

@implementation MMLoadImageCache{
    NSMutableDictionary* loadedImages;
    NSMutableArray* orderedKeys;
    int loadedBytes;
}

-(id) init{
    @synchronized([MMLoadImageCache class]){
        if((self = [super init])){
            loadedImages = [NSMutableDictionary dictionary];
            orderedKeys = [NSMutableArray array];
        }
    }
    return self;
}

+ (MMLoadImageCache *) sharedInstance {
    static dispatch_once_t onceToken;
    static MMLoadImageCache *manager;
    dispatch_once(&onceToken, ^{
        manager = [[[MMLoadImageCache class] alloc] init];
    });
    return manager;
}

-(int) memoryOfLoadedImages{
    return loadedBytes;
}

#pragma mark - Load Images

-(BOOL) containsPathInCache:(NSString*)path{
    BOOL contains = NO;
    @synchronized(self){
        contains = [orderedKeys containsObject:path];
    }
    return contains;
}


static int count = 0;
-(UIImage*) imageAtPath:(NSString*)path{
    UIImage* cachedImage = nil;
    @synchronized(self){
        cachedImage = [loadedImages objectForKey:path];
    }
    if(!cachedImage){
        @synchronized(self){
            if([orderedKeys containsObject:path]){
                // we don't have an image, but our path is
                // in cache. this means there was nothing on disk
                return nil;
            }
        }
        cachedImage = [UIImage imageWithContentsOfFile:path];
        count++;
        @synchronized(self){
            if(cachedImage){
                [loadedImages setObject:cachedImage forKey:path];
            }
            if(path){
                [orderedKeys removeObject:path];
                [orderedKeys insertObject:path atIndex:0];
            }else{
                DebugLog(@"how did we get nil path?");
            }
            [self ensureCacheSize];
            
            loadedBytes += [cachedImage uncompressedByteSize];
        }
    }
    return cachedImage;
}

-(void) ensureCacheSize{
    @synchronized(self){
        while([orderedKeys count] > kMMLoadImageCacheSize){
            [self clearCacheForPath:[orderedKeys lastObject]];
        }
    }
}

-(void) clearCacheForPath:(NSString*)path{
    if(!path) return;
    @synchronized(self){
        UIImage* cachedImage = [loadedImages objectForKey:path];
        if(cachedImage){
            loadedBytes -= [cachedImage uncompressedByteSize];
        }
        [loadedImages removeObjectForKey:path];
        [orderedKeys removeObject:path];
    }
}

-(void) updateCacheForPath:(NSString*)path toImage:(UIImage*)image{
    @synchronized(self){
        [self clearCacheForPath:path];
        if(image){
            UIImage* cachedImage = [loadedImages objectForKey:path];
            if(cachedImage){
                loadedBytes -= [cachedImage uncompressedByteSize];
            }
            [loadedImages setObject:image forKey:path];
            loadedBytes += [image uncompressedByteSize];
        }else{
            UIImage* cachedImage = [loadedImages objectForKey:path];
            if(cachedImage){
                loadedBytes -= [cachedImage uncompressedByteSize];
            }
            [loadedImages removeObjectForKey:path];
        }
        [orderedKeys insertObject:path atIndex:0];
        [self ensureCacheSize];
    }
}

#pragma mark - Profiling Helpers

-(NSInteger) numberOfItemsHeldInCache{
    return [loadedImages count];
}

@end
