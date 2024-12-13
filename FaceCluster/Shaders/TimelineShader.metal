//
//  TimelineShader.metal
//  FaceCluster
//
//  Created by El-Mundo on 12/12/2024.
//

#include <metal_stdlib>
using namespace metal;

#include "Misc/ClusterPalette.h"
#include "C-Bridging.h"

typedef struct {
    float2 uv;
    float4 pos [[position]];
    uint sliceIndex;
} Vertext;

static constexpr constant float2 TEXT_V[] = {{0, -0.5}, {0, 0}, {0.5, 0}, {0, -0.5}, {0.5, 0}, {0.5, -0.5}};
static constexpr constant float2 TEXT_T[] = {{0, 1}, {0, 0}, {1, 0}, {0, 1}, {1, 0}, {1, 1}};

vertex Vertext textVertex(const device float & width [[ buffer(0) ]],
                          constant Uniforms& uniforms [[buffer(1)]],
                          uint vertexID [[ vertex_id ]]) {
    uint word = vertexID / 36;
    uint character = vertexID % 36;
    uint ver = character % 6;
    uint minute = word / 4;
    uint second = word % 4;
    character /= 6;
    
    float2 off = TEXT_V[ver];
    float x = (word * 15 - uniforms.camera.x) * uniforms.mousePos.y + character * 0.2 - 0.75 + off.x;
    float y = off.y;
    float2 uv = TEXT_T[ver];
    
    float2 aspectRatio = simd_float2(1 / uniforms.aspect, 1);
    x = (x) * uniforms.scale * aspectRatio.x;
    y = (y - uniforms.camera.y) * uniforms.scale * aspectRatio.y;
    float z = 0.0f;
    float4 pos = float4(x, y, z, 1.0);
    
    Vertext out;
    out.pos = pos;
    out.uv = uv;
    if(character == 3) {
        out.sliceIndex = 10;
    } else if(character == 0) {
        if(minute < 100) {
            out.sliceIndex = 0;
        } else {
            out.sliceIndex = minute / 100;
        }
    } else if(character == 1) {
        if(minute < 10) {
            out.sliceIndex = 0;
        } else {
            out.sliceIndex = minute / 10;
        }
    } else if(character == 2) {
        out.sliceIndex = minute % 10;
    } else if(character == 4) {
        if(second == 0) {
            out.sliceIndex = 0;
        } else if(second == 1) {
            out.sliceIndex = 1;
        } else if(second == 2) {
            out.sliceIndex = 3;
        } else {
            out.sliceIndex = 4;
        }
    } else if(character == 5) {
        if(second == 1) {
            out.sliceIndex = 5;
        } else if(second == 3) {
            out.sliceIndex = 5;
        } else {
            out.sliceIndex = 0;
        }
    }
    return out;
}

fragment float4 textFragment(texture2d_array<float> fontTexture [[ texture(0) ]],
                             Vertext v [[stage_in]]) {
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    float4 color = fontTexture.sample(colorSampler, v.uv, v.sliceIndex);
    if(color.r < 0.5) {
        return float4(1, 1, 1, 0);
    } else {
        return color;
    }
}

vertex float4 vertex_main(const device float & width [[ buffer(0) ]],
                          constant Uniforms& uniforms [[buffer(1)]],
                          uint vertexID [[ vertex_id ]]) {
    float2 aspectRatio = simd_float2(1 / uniforms.aspect, 1);
    float x = ((vertexID % 2 == 0 ? 0 : width) - uniforms.camera.x) * uniforms.mousePos.y * uniforms.scale * aspectRatio.x;
    float y = ((vertexID / 2) - uniforms.camera.y) * uniforms.scale * aspectRatio.y;
    float z = 0.0f;
    return float4(x, y, z, 1.0);
}

// Fragment Shader
fragment float4 fragment_main() {
    return float4(1.0, 1.0, 1.0, 1.0);
}

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
    uint16_t texIndex;
    bool showTexture;
    bool darken;
    bool useBGR;
} MeshletVertex;
typedef struct
{
    float3 color;
} MeshletPrimitive;

typedef struct {
    packed_uint3 mapPosition;
    uint16_t type;
    bool showTexture;
    bool darken;
    bool useBGR;
    //float4x4 modelMatrix;
    simd_float3 aspectRatio;
    uint16_t primitiveCount;
    uint16_t vertexCount;
    float3 vertices[4];
    uint8_t indices[6];
    uint16_t textureIndex;
} ChunkPayload;
static constexpr constant uint16_t MAX_MESHLET_VERTICES = 8;
static constexpr constant uint32_t MAX_MESHLET_PRIMS = MAX_MESHLET_VERTICES * 2;
static constexpr constant float3 RECTANGLE_MESH[] = {{-0.5, 0.5, 0}, {0.5, 0.5, 0}, {0.5, -0.5, 0}, {-0.5, -0.5, 0}};
static constexpr constant float3 POINT_MESH[] = {{-0.05, 0.05, 0}, {0.05, 0.05, 0}, {0.05, -0.05, 0}, {-0.05, -0.05, 0}};
static constexpr constant float2 RECTANGLE_TEX[] = {{0, 0}, {1, 0}, {1, 1}, {0, 1}};
using AAPLTriangleMeshType = metal::mesh<MeshletVertex, MeshletPrimitive, MAX_MESHLET_VERTICES, MAX_MESHLET_PRIMS, metal::topology::triangle>;

[[object, max_total_threads_per_threadgroup(8), max_total_threadgroups_per_mesh_grid(1)]]
void timeObjectShader(object_data ChunkPayload& payload [[payload]],
                        mesh_grid_properties meshGridProperties,
                        constant Uniforms& uniforms [[ buffer(1) ]],
                        constant FaceMap* faceMaps [[ buffer(0) ]],
                        constant unsigned int* facesCount [[ buffer(2)]],
                        constant uint16_t* colors [[ buffer(3)]],
                        uint3 positionInGrid [[threadgroup_position_in_grid]])
{
    uint faceIndex;
    if(uniforms.multipleSelect) {
        uint batchIndex = facesCount[1];
        faceIndex = positionInGrid.x + batchIndex * uint(FaceNetworkConstantsBatchSize);
        if (faceIndex >= facesCount[0])
            return;
    } else {
        faceIndex = positionInGrid.x;
    }
    
    float2 pos = faceMaps[faceIndex].pos;
    payload.textureIndex = 0;
    
    payload.primitiveCount = 2;
    payload.vertexCount = 4;
    payload.aspectRatio = simd_float3(1 / uniforms.aspect, 1, 1);
    
    payload.useBGR = uniforms.useBGR;
    if(uniforms.multipleSelect) {
        payload.textureIndex = positionInGrid.x;
    } else {
        payload.textureIndex = colors[faceIndex];
    }
    payload.showTexture = uniforms.multipleSelect;
    
    payload.indices[0] = 0;
    payload.indices[1] = 1;
    payload.indices[2] = 2;
    payload.indices[3] = 0;
    payload.indices[4] = 2;
    payload.indices[5] = 3;
    
    float2 off2d = pos - uniforms.camera;
    float3 offset = {off2d[0], off2d[1], 0.01};
    float3 stretch3d = float3(uniforms.mousePos.y, 1, 1);
    offset *= stretch3d;

    if(!uniforms.multipleSelect) {
        // Copy the vertex data into the payload.
        for (size_t i = 0; i < payload.vertexCount; i++)
        {
            payload.vertices[i] = (offset + POINT_MESH[i] * uniforms.mousePos.x) * uniforms.scale;
        }
    } else {
        for (size_t i = 0; i < payload.vertexCount; i++)
        {
            payload.vertices[i] = (offset + RECTANGLE_MESH[i] * uniforms.mousePos.x) * uniforms.scale;
        }
    }
    
    meshGridProperties.set_threadgroups_per_grid(uint3(1, 1, 1));
}

[[mesh, max_total_threads_per_threadgroup(8)]]
void timeMeshletShader(AAPLTriangleMeshType output,
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
        float4 pos = float4(payload.vertices[lid] * payload.aspectRatio, 1.0f);
        //v.position = payload.modelMatrix * pos;
        v.position = pos;
        v.texCoord = RECTANGLE_TEX[lid];
        v.texIndex = payload.textureIndex;
        v.showTexture = payload.showTexture;
        v.darken = payload.darken;
        v.useBGR = payload.useBGR;
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

fragment float4 timeFragmentShader(MeshletVertex in [[stage_in]],
                               texture2d_array<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    if(in.showTexture) {
        constexpr sampler colorSampler(mip_filter::linear,
                                       mag_filter::linear,
                                       min_filter::linear);
        
        half4 colorSample = colorMap.sample(colorSampler, in.texCoord.xy, in.texIndex);
        return float4(colorSample);
    } else {
        float4 colorSample = float4(clusterPalette[in.texIndex % 14], 1);
        return colorSample;
    }
}
