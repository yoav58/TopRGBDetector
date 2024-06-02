//
//  ComputeShader.metal
//  TopRGBDetector
//
//  Created by יואב אליאב on 01/06/2024.
//

#include <metal_stdlib>
using namespace metal;

struct ColorCount {
    uint color;
    uint count;
};


//// this function is metal function that do couple of things:
/// 1) convert from YUV to rgb.
/// 2) count color occurrences.
/// Output: an array of size of all the possible rgb colors (256 * 256 * 256)  where each index represents a unique RGB color, and the value at each index represents the count of that color.
/// this function made with help of chatgpt(mainly the convertion part)
kernel void computeYuvToRgb(
    texture2d<float, access::read> yTexture [[texture(0)]],
    texture2d<float, access::read> uvTexture [[texture(1)]],
    device atomic_uint* histogram [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= yTexture.get_width() || gid.y >= yTexture.get_height()) return;

    // Reading the Y component from the Y texture
    float Y = yTexture.read(gid).r;  // Y plane is single channel

    // For UV components.
    uint2 uvGid = gid / 2;
    if (uvGid.x >= uvTexture.get_width() || uvGid.y >= uvTexture.get_height()) return;
    float2 UV = uvTexture.read(uvGid).rg;  // UV plane might be packed in a two-channel texture

    float U = UV.r - 0.5;
    float V = UV.g - 0.5;

    // Convert YUV to RGB (used chatgpt for this formulas)
    float R = Y + 1.403 * V;
    float G = Y - 0.344 * U - 0.714 * V;
    float B = Y + 1.770 * U;

    // Convert to 0-255 range and calculate index
    uint r = clamp(uint(R * 255.0), 0u, 255u);
    uint g = clamp(uint(G * 255.0), 0u, 255u);
    uint b = clamp(uint(B * 255.0), 0u, 255u);
    uint colorIndex = (r << 16) | (g << 8) | b;

    // Update histogram
    atomic_fetch_add_explicit(&histogram[colorIndex], 1, memory_order_relaxed);
}







/// this function  filter all the elements that cant be in the top 5, since the sort operation is very heavy, the cpu cant handle this. so i did ״Reduction"
/// the reduction  working this way:
/// 1) each thread responsible for segment of the histogram, for example thread1 is responsible for histogram[0..<1000], thread2 for histogram[1000..<2000] and so on...
/// 2) each thread find  the top five colors in is segment. and after he finds the top 5 he write them into global buffer.
/// 3) the global buffer size is numberofThreads * 5, so each thread  has its own  segment to write, for example thread1 write to the global buffer at indexes 0..4, thread2 write at indexes 5...9 and so on... in this way all the threads dont intersecting.
/// with this reduction i can be sure  that the top 5 colors will be in the new array.
/// Output: a new array that it much smaller. but also 100% will contains the top 5 colors.
kernel void findLocalTopColors(
    device uint* histogram [[buffer(0)]],
    device ColorCount* globalTopColors [[buffer(1)]],
    constant uint& segmentSize [[buffer(2)]],
    uint tid [[thread_position_in_grid]]
) {
    uint start = tid * segmentSize;
    uint end = start + segmentSize;
    
    // Local top colors initialization and sorting logic
    ColorCount localTop[5] = { {0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0} };

    for (uint i = start; i < end; ++i) {
        uint count = histogram[i]; // Direct access as no modification occurs here
        for (int j = 0; j < 5; ++j) {
            if (count > localTop[j].count) {
                for (int k = 4; k > j; --k) {
                    localTop[k] = localTop[k - 1]; // Shift down (to keep the array sorted)
                }
                localTop[j] = (ColorCount){i, count}; // Insert new top color
                break;
            }
        }
    }

    // Output the local top colors to the global buffer space designated for this thread
    for (int j = 0; j < 5; ++j) {
        globalTopColors[tid * 5 + j] = localTop[j];
    }
}




