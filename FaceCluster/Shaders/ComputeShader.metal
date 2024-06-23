//
//  ComputeShader.metal
//  FaceCluster
//
//  Created by El-Mundo on 22/06/2024.
//

#include <metal_stdlib>
using namespace metal;

#include "C-Bridging.h"

kernel void pointsEuclidean(const device float2* points [[ buffer(0) ]],
                            device PairedDistance* results [[ buffer(1) ]],
                            const device float& ths [[ buffer(2) ]],
                            const device uint& count [[ buffer(3) ]],
                            uint3 id [[ thread_position_in_grid ]]) {

    uint hal = (count % 2 == 0) ? (count / 2) : ((count + 1) / 2);
    PairedDistance out = PairedDistance();
    if(id.x == id.y || id.y >= hal || id.x >= count) {
        out.paired = false;
        out.index = uint2(id.x, id.y);
        results[id.x + id.y * count] = out;
        return;
    }
    
    float2 p1, p2;
    uint2 index;
    if(id.x > id.y) {
        index.x = id.y;
        index.y = id.x;
    } else {
        index.x = count - id.y - 1;
        index.y = count - id.x - 1;
    }
    p1 = points[ index.x ];
    p2 = points[ index.y ];
    float dis = distance(p1, p2);
    
    out.paired = dis < ths;
    out.index = index;
    
    results[id.x + id.y * count] = out;
}

