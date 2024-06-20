//
//  C-Bridging.h
//  FaceCluster
//
//  Created by El-Mundo on 19/06/2024.
//

#ifndef C_Bridging_h
#define C_Bridging_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

typedef NS_ENUM(EnumBackingType, BufferIndex)
{
    BufferIndexObject = 0,
    BufferIndexFaceCount  = 1,
    BufferIndexUniforms      = 2
};

typedef NS_ENUM(EnumBackingType, FaceNetworkConstants)
{
    FaceNetworkConstantsBatchSize = 256
};

typedef NS_ENUM(EnumBackingType, TextureIndex)
{
    TextureIndexColor    = 0,
};

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
} Uniforms;

#endif /* C_Bridging_h */
