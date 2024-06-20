//
//  NetworkRender.metal
//  FaceCluster
//
//  Created by El-Mundo on 19/06/2024.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

#import "C-Bridging.h"

static constexpr constant uint16_t MAX_MESHLET_VERTICES = 8;
static constexpr constant uint32_t MAX_MESHLET_PRIMS = MAX_MESHLET_VERTICES * 2;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
    uint16_t texIndex;
} MeshletVertex;

typedef struct
{
    float3 color;
} MeshletPrimitive;

typedef struct {
    packed_uint3 mapPosition;
    uint16_t type;
    float4x4 modelMatrix;
    uint16_t primitiveCount;
    uint16_t vertexCount;
    float3 vertices[4];
    uint8_t indices[6];
    uint16_t textureIndex;
} ChunkPayload;

static constexpr constant float3 RECTANGLE_MESH[] = {{-0.5, 0.5, 0}, {0.5, 0.5, 0}, {0.5, -0.5, 0}, {-0.5, -0.5, 0}};
static constexpr constant float2 RECTANGLE_TEX[] = {{0, 0}, {1, 0}, {1, 1}, {0, 1}};

using AAPLTriangleMeshType = metal::mesh<MeshletVertex, MeshletPrimitive, MAX_MESHLET_VERTICES, MAX_MESHLET_PRIMS, metal::topology::triangle>;

[[object, max_total_threads_per_threadgroup(8), max_total_threadgroups_per_mesh_grid(1)]]
void faceObjectShader(object_data ChunkPayload& payload [[payload]],
                         mesh_grid_properties meshGridProperties,
                         constant Uniforms& uniforms [[ buffer(BufferIndexUniforms) ]],
                         constant simd_float2* faceMap [[ buffer(BufferIndexObject) ]],
                         constant unsigned int* facesCount [[ buffer(BufferIndexFaceCount)]],
                         uint3 positionInGrid [[threadgroup_position_in_grid]])
{
    uint batchIndex = facesCount[1];
    uint faceIndex = positionInGrid.x + batchIndex * uint(FaceNetworkConstantsBatchSize);
    if (faceIndex >= facesCount[0])
        return;
    
    payload.textureIndex = positionInGrid.x;
    
    payload.primitiveCount = 2;
    payload.vertexCount = 4;
    
    payload.indices[0] = 0;
    payload.indices[1] = 1;
    payload.indices[2] = 2;
    payload.indices[3] = 0;
    payload.indices[4] = 2;
    payload.indices[5] = 3;
    
    float2 off2d = faceMap[faceIndex];
    float3 offset =  {off2d[0], off2d[1], 0.0};

    // Copy the vertex data into the payload.
    for (size_t i = 0; i < payload.vertexCount; i++)
    {
        payload.vertices[i] = offset + RECTANGLE_MESH[i];
    }
    
    payload.modelMatrix = uniforms.projectionMatrix * uniforms.modelViewMatrix;
    meshGridProperties.set_threadgroups_per_grid(uint3(1, 1, 1));
}

[[mesh, max_total_threads_per_threadgroup(8)]]
void faceMeshletShader(AAPLTriangleMeshType output,
                                 const object_data ChunkPayload& payload [[payload]],
                                 uint lid [[thread_index_in_threadgroup]],
                                 uint tid [[threadgroup_position_in_grid]])
{
    if(lid == 0) {
        output.set_primitive_count(payload.primitiveCount);
    }
    
    if (lid < payload.vertexCount)
    {
        MeshletVertex v;
        float4 pos = float4(payload.vertices[lid], 1.0f);
        v.position = payload.modelMatrix * pos;
        v.texCoord = RECTANGLE_TEX[lid];
        v.texIndex = payload.textureIndex;
        //v.normal = normalize(payload.vertices[lid].normal.xyz);
        output.set_vertex(lid, v);
    }
    
    // Set the constant data for the entire primitive.
    if (lid < payload.primitiveCount)
    {
        MeshletPrimitive p;
        p.color = {1.0, 1.0, 1.0};
        output.set_primitive(lid, p);

        // Set the output indices.
        uint i = (3*lid);
        output.set_index(i+0, payload.indices[i+0]);
        output.set_index(i+1, payload.indices[i+1]);
        output.set_index(i+2, payload.indices[i+2]);
    }
}

fragment float4 fragmentShader(MeshletVertex in [[stage_in]],
                               //constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d_array<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy, in.texIndex);

    //return float4(colorSample);
    return float4(colorSample.g, colorSample.r, colorSample.a, colorSample.b);
}
