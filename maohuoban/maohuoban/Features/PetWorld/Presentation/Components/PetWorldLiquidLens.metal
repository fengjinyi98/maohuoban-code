#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// petWorldCapsuleDistance 胶囊距离场
// 核心职责：
// - 描述频道选中胶囊的边界距离
// - 为折射 shader 提供内外区域判断
float petWorldCapsuleDistance(float2 point, float2 halfSize, float radius) {
    float2 delta = abs(point) - halfSize + radius;
    return length(max(delta, 0.0)) + min(max(delta.x, delta.y), 0.0) - radius;
}

[[stitchable]] half4 petWorldLiquidLens(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float positionX,
    float refractionAmount,
    float refractionDepth
) {
    float2 pillCenter = size * 0.5 + float2(positionX, 0.0);
    float2 local = position - pillCenter;
    float2 halfSize = size * 0.5;
    float radius = size.y * 0.5;

    float distance = petWorldCapsuleDistance(local, halfSize, radius);

    if (distance > 0.0) {
        return layer.sample(position);
    }

    float2 outward = normalize(float2(
        petWorldCapsuleDistance(local + float2(1, 0), halfSize, radius)
            - petWorldCapsuleDistance(local - float2(1, 0), halfSize, radius),
        petWorldCapsuleDistance(local + float2(0, 1), halfSize, radius)
            - petWorldCapsuleDistance(local - float2(0, 1), halfSize, radius)
    ));

    float depthInside = -distance;
    float edgeAmount = 1.0 - smoothstep(0.0, refractionDepth, depthInside);
    float bend = edgeAmount * edgeAmount * refractionAmount;

    return layer.sample(position - outward * bend);
}
