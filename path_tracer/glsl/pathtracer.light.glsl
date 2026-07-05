
vec2 normalize_uv = vec2(0.1591, 0.3183);
vec2 sampleSphericalMap(vec3 v) {
    // U is in the range [-PI, PI], V is [-PI/2, PI/2]
    vec2 uv = vec2(atan(v.z, v.x), asin(v.y));
    // Convert UV to [-0.5, 0.5] in U&V
    uv *= normalize_uv;
    // Convert UV to [0, 1]
    uv += 0.5;
    return uv;
}

vec3 sampleFromInsideSphere(vec2 xi, out float pdf) {
//    Point3f pObj = WarpFunctions::squareToSphereUniform(xi);

//    Intersection it;
//    it.normalGeometric = glm::normalize( transform.invTransT() *pObj );
//    it.point = Point3f(transform.T() * glm::vec4(pObj.x, pObj.y, pObj.z, 1.0f));

//    *pdf = 1.0f / Area();

//    return it;
    return vec3(0.);
}

#if N_AREA_LIGHTS
vec3 DirectSampleAreaLight(int idx,
                           vec3 view_point, vec3 view_nor,
                           int num_lights,
                           out vec3 wiW, out float pdf) {
    AreaLight light = areaLights[idx];
    int type = light.shapeType;
    Ray shadowRay;

    if(type == RECTANGLE) {
        // TODO hw03
        // get a point random on rectangle
        vec3 point_random = vec3(rng(), rng(), 0);
        //[-1,1]
        point_random.x = point_random.x * 2.f - 1.f;
        point_random.y = point_random.y * 2.f - 1.f;
        point_random = vec3(light.transform.T * vec4(point_random, 1));


        float area = 4 * light.transform.scale.x * light.transform.scale.y;
        pdf = float(1.f / area);

        vec3 light_nor = light.transform.invTransT * vec3(0.f, 0.f, 1.f);
        wiW = normalize(point_random - view_point);

        float radius = distance(point_random, view_point) * distance(point_random, view_point);
        //absdot n wi
        float cos_theta = max(dot(light_nor, -wiW), 0);
        if (cos_theta == 0.f) {
            pdf = 0;
        } else {
            pdf *= radius / cos_theta;
        }

        Ray ray = SpawnRay(view_point, wiW);
        Intersection isect = sceneIntersect(ray);

        if (dot(isect.Le, isect.Le) <= 0.f) {
            return vec3(0.f);
        } else {
            return num_lights * light.Le;
        }

    }
    else if(type == SPHERE) {

        Transform tr = areaLights[idx].transform;

        vec2 xi = vec2(rng(), rng());

        vec3 center = vec3(tr.T * vec4(0.f, 0., 0.f, 1.f));
        vec3 centerToRef = normalize(center - view_point);
        vec3 tan, bit;

        coordinateSystem(centerToRef, tan, bit);

        vec3 pOrigin;
        if(dot(center - view_point, view_nor) > 0) {
            pOrigin = view_point + view_nor * RayEpsilon;
        }
        else {
            pOrigin = view_point - view_nor * RayEpsilon;
        }

        if(dot(pOrigin - center, pOrigin - center) <= 1.f){
            return sampleFromInsideSphere(xi, pdf);
        }

        //sphere simaple
        float max_sin = 1 / dot(view_point - center, view_point - center);
        float max_cos = sqrt(max(0.f, 1.f - max_sin));
        float cos_Theta = (1.f - xi.x) + xi.x * max_cos;
        float sin_Theta = sqrt(max(0.f, 1.f- cos_Theta * cos_Theta));
        float phi = TWO_PI * xi.y;

        float dc = distance(view_point, center);
        float ds = dc * cos_Theta - sqrt(max(0.0f, 1 - dc * dc * sin_Theta * sin_Theta));

        float cosAlpha = (dc * dc + 1 - ds * ds) / (2 * dc * 1);
        float sinAlpha = sqrt(max(0.f, 1.f - cosAlpha * cosAlpha));
        //space == 1 pobj = nbj
        vec3 nObj = sinAlpha * cos(phi) * -tan + sinAlpha * sin(phi) * -bit + cosAlpha * -centerToRef;
        vec3 pObj = vec3(nObj);

        shadowRay = SpawnRay(view_point, normalize(vec3(tr.T * vec4(pObj, 1.f)) - view_point));
        wiW = shadowRay.direction;
        pdf = 1.f / (TWO_PI * (1 - max_cos));
    }

    //return vec3(0.);
    Intersection isect = sceneIntersect(shadowRay);
    if(isect.obj_ID == areaLights[idx].ID) {
        return num_lights * areaLights[idx].Le;
    }
}
#endif

#if N_POINT_LIGHTS
vec3 DirectSamplePointLight(int idx,
                            vec3 view_point, int num_lights,
                            out vec3 wiW, out float pdf) {
    PointLight light = pointLights[idx];
    // TODO hw03
    //return vec3(0.);
    wiW = normalize(vec3(light.pos - view_point));
    pdf = 1.f;
    Ray shadowRay = SpawnRay(view_point, wiW);
    Intersection shadowIsect = sceneIntersect(shadowRay);
    if (shadowIsect.t <= length(view_point - light.pos)) {
        return vec3(0.);
    } else {
        return num_lights * light.Le / (length(view_point - light.pos) * length(view_point - light.pos));
    }
}
#endif

#if N_SPOT_LIGHTS
vec3 DirectSampleSpotLight(int idx,
                           vec3 view_point, int num_lights,
                           out vec3 wiW, out float pdf) {
    SpotLight light = spotLights[idx];
    // TODO hw03
    //return vec3(0.);
    vec3 light_posistion = vec3(light.transform.T * vec4(0, 0, 0, 1));
    wiW = normalize(vec3(light_posistion - view_point));
    vec3 light_normal = light.transform.invTransT * vec3(0, 0, 1);
    float angle = degrees(acos(dot(light_normal, -wiW)));
    pdf = 1.f;

    if (angle < light.outerAngle) {
        float reduction = 0.f;
        if (angle > light.innerAngle) {
            reduction = 1 - smoothstep(light.innerAngle, light.outerAngle, angle);
        } else {
            reduction = 1.f;
        }

        Ray shadowRay = SpawnRay(view_point, wiW);
        Intersection shadowIsect = sceneIntersect(shadowRay);

        if (shadowIsect.t <= length(view_point - light_posistion)) {
            return vec3(0);
        } else {
            return reduction * num_lights * light.Le / (length(view_point - light_posistion) * length(view_point - light_posistion));
        }
    }
    return vec3(0.);
}
#endif

// vec3 Sample_Li(vec3 view_point, vec3 nor, out vec3 wiW, out float pdf) {
//     // Choose a random light from among all of the
//     // light sources in the scene, including the environment light
//     int num_lights = N_LIGHTS;

// #define ENV_MAP 0
// #if ENV_MAP
//     int num_lights = N_LIGHTS + 1;
// #endif
//     int randomLightIdx = int(rng() * num_lights);

//     // Chose an area light
//     if(randomLightIdx < N_AREA_LIGHTS) {
// #if N_AREA_LIGHTS
//         return DirectSampleAreaLight(randomLightIdx, view_point, nor, num_lights,
//                                      wiW, pdf);
// #endif
//     }
//     // Chose a point light
//     else if(randomLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS) {
// #if N_POINT_LIGHTS
//         return DirectSamplePointLight(randomLightIdx - N_AREA_LIGHTS,
//                                       view_point, num_lights, wiW, pdf);
// #endif
//     }
//     // Chose a spot light
//     else if(randomLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS + N_SPOT_LIGHTS) {
// #if N_SPOT_LIGHTS
//         return DirectSampleSpotLight(randomLightIdx - N_AREA_LIGHTS - N_POINT_LIGHTS,
//                                      view_point, num_lights, wiW, pdf);
// #endif
//     }
//     // Chose the environment light
//     else {
//         // TODO

//     }
//     return vec3(0.);
// }

// vec3 Sample_Li(vec3 view_point, vec3 nor,
//                        out vec3 wiW, out float pdf,
//                        out int chosenLightIdx,
//                        out int chosenLightID) {
//     // Choose a random light from among all of the
//     // light sources in the scene, including the environment light
//     int num_lights = N_LIGHTS;
// #define ENV_MAP 0
// #if ENV_MAP
//     int num_lights = N_LIGHTS + 1;
// #endif
//     int randomLightIdx = int(rng() * num_lights);
//     chosenLightIdx = randomLightIdx;
//     // Chose an area light
//     if(randomLightIdx < N_AREA_LIGHTS) {
// #if N_AREA_LIGHTS
//         chosenLightID = areaLights[chosenLightIdx].ID;
//         return DirectSampleAreaLight(randomLightIdx, view_point, nor, num_lights, wiW, pdf);
// #endif
//     }
//     // Chose a point light
//     else if(randomLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS) {
// #if N_POINT_LIGHTS
//         chosenLightID = pointLights[randomLightIdx - N_AREA_LIGHTS].ID;
//         return DirectSamplePointLight(randomLightIdx - N_AREA_LIGHTS, view_point, num_lights, wiW, pdf);
// #endif
//     }
//     // Chose a spot light
//     else if(randomLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS + N_SPOT_LIGHTS) {
// #if N_SPOT_LIGHTS
//         chosenLightID = spotLights[randomLightIdx - N_AREA_LIGHTS - N_POINT_LIGHTS].ID;
//         return DirectSampleSpotLight(randomLightIdx - N_AREA_LIGHTS - N_POINT_LIGHTS, view_point, num_lights, wiW, pdf);
// #endif
//     }
//     // Chose the environment light
//     else {
//         chosenLightID = -1;
//         // TODO
//     }
//     return vec3(0.);
// }

vec3 Sample_Li(vec3 view_point, vec3 nor,
                       out vec3 wiW, out float pdf,
                       out int chosenLightIdx,
                       out int chosenLightID,
                       out int chosenLightType) {
    // Choose a random light from among all of the
    // light sources in the scene, including the environment light
    int num_lights = N_LIGHTS;
#define ENV_MAP 1
#if ENV_MAP
    num_lights = N_LIGHTS + 1;
#endif
    int randomLightIdx = int(rng() * num_lights);
    chosenLightIdx = randomLightIdx;
    // Chose an area light
    if(randomLightIdx < N_AREA_LIGHTS) {
#if N_AREA_LIGHTS
        chosenLightID = areaLights[chosenLightIdx].ID;
        chosenLightType = 1;
        return DirectSampleAreaLight(randomLightIdx, view_point, nor, num_lights, wiW, pdf);
#endif
    }
    // Chose a point light
    else if(randomLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS) {
#if N_POINT_LIGHTS
        chosenLightID = pointLights[randomLightIdx - N_AREA_LIGHTS].ID;
        chosenLightType = 2;
        return DirectSamplePointLight(randomLightIdx - N_AREA_LIGHTS, view_point, num_lights, wiW, pdf);
#endif
    }
    // Chose a spot light
    else if(randomLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS + N_SPOT_LIGHTS) {
#if N_SPOT_LIGHTS
        chosenLightID = spotLights[randomLightIdx - N_AREA_LIGHTS - N_POINT_LIGHTS].ID;
        chosenLightType = 3;
        return DirectSampleSpotLight(randomLightIdx - N_AREA_LIGHTS - N_POINT_LIGHTS, view_point, num_lights, wiW, pdf);
#endif
    }
    // Chose the environment light
    else {
        chosenLightID = -1;
        // TODO
        //chosenLightType = 4;
        vec3 wiW = LocalToWorld(nor) * squareToHemisphereCosine(vec2(rng(), rng()));
        vec2 uv = sampleSphericalMap(wiW);

        //pdf = Pdf_Li(view_point, nor, wiW, INFINITY);
        pdf = squareToHemisphereCosinePDF(wiW);

        vec3 envColor = texture(u_EnvironmentMap, uv).rgb;
        return envColor;
        //return vec3(0.);
    }
    return vec3(0.);
}



float UniformConePdf(float cosThetaMax) {
    return 1 / (2 * PI * (1 - cosThetaMax));
}

float SpherePdf(vec3 view_point, vec3 view_nor, vec3 p, vec3 wi,
                Transform transform, float radius) {
    vec3 pCenter = (transform.T * vec4(0, 0, 0, 1)).xyz;
    // Return uniform PDF if point is inside sphere
    vec3 pOrigin = p + view_nor * 0.0001;
    // If inside the sphere
    if(DistanceSquared(pOrigin, pCenter) <= radius * radius) {
//        return Shape::Pdf(ref, wi);
        // To be provided later
        return 0.f;
    }
    // Compute general sphere PDF
//    float sinThetaMax2 = radius * radius / DistanceSquared(p, pCenter);
    float sinThetaMax2 = 1 / dot(view_point - pCenter, view_point - pCenter); // Again, radius is 1
    float cosThetaMax = sqrt(max(0.f, 1.f - sinThetaMax2));
    return UniformConePdf(cosThetaMax) / transform.scale.x * transform.scale.x;
}



float Pdf_Li(vec3 view_point, vec3 nor, vec3 wiW, int chosenLightIdx) {
    Ray ray = SpawnRay(view_point, wiW);
    // Area light
    if(chosenLightIdx < N_AREA_LIGHTS) {
#if N_AREA_LIGHTS
        Intersection isect = areaLightIntersect(areaLights[chosenLightIdx],
                                                ray);
        if(isect.t == INFINITY) {
            return 0.;
        }
        vec3 light_point = ray.origin + isect.t * wiW;
        // If doesn't intersect, 0 PDF
        if(isect.t == INFINITY) {
            return 0.;
        }
        int type = areaLights[chosenLightIdx].shapeType;
        if(type == RECTANGLE) {
            Transform tr = areaLights[chosenLightIdx].transform;
            vec3 pos = vec3(tr.T * vec4(0,0,0,1));
            // Technically half side len
            vec2 sideLen = tr.scale.xy;
            vec3 nor = normalize(tr.invTransT * vec3(0,0,1));
            // Convert PDF from w/r/t surface area to w/r/t solid angle
            float r2 = isect.t * isect.t;
            // r*r / (cos(theta_w) * area)
            return r2 / (AbsDot(ray.direction, nor) * 4 * sideLen.x * sideLen.y);
        }
        else if(type == SPHERE) {
            return SpherePdf(view_point, isect.nor, light_point, wiW,
                                  areaLights[chosenLightIdx].transform,
                                  1.f);
        }
#endif
    }
    // Point light or spot light
    else if(chosenLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS ||
            chosenLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS + N_SPOT_LIGHTS) {
        return 0;
    }
    // Env map
    else {
        vec3 wi = WorldToLocal(nor) * wiW;
        return squareToHemisphereCosinePDF(wi);
    }
}

float PowerHeuristic(int nf, float fPdf, int ng, float gPdf) {
    // TODO
    //return 0.f;

    if (fPdf == 0.f && gPdf == 0.f) {
        return 0.f;
    }
    float f = nf * fPdf;
    float g = ng * gPdf;

    return (f * f) / (f * f + g * g);
}

vec3 ComputeDirectLight_MIS(Intersection isect,Ray ray) {
    vec3 L = vec3(0.0);

    if (isect.Le != vec3(0.0)) {
        return isect.Le;
    }

    vec3 view_point;
    int sampledType;
    vec3 wiW_lightSampled;
    vec3 bsdf_lightSampled;

    float pdf_bsdf_lightSampled;
    float pdf_light;

    int chosenLightIdx, chosenLightID;
    int isLightType;
    view_point = ray.origin + isect.t * ray.direction;

    if (isect.t == INFINITY) {
        return L;
    }

    vec3 Li_lightSampled = Sample_Li(view_point,
                                     isect.nor, wiW_lightSampled,
                                     pdf_light,
                                     chosenLightIdx,
                                     chosenLightID,
                                     isLightType);

    bsdf_lightSampled = f(isect, -ray.direction, wiW_lightSampled);


    if (pdf_light > 0.0 && Li_lightSampled != vec3(0.0)) {

        pdf_bsdf_lightSampled = Pdf(isect, -ray.direction, wiW_lightSampled);
        float weight_light = PowerHeuristic(1, pdf_light,
                                            1, pdf_bsdf_lightSampled);
        if (isLightType == 1){
#if N_AREA_LIGHTS
           L +=  weight_light * Li_lightSampled * bsdf_lightSampled * AbsDot(wiW_lightSampled, isect.nor) / pdf_light;
#endif
        }else if (isLightType == 2) {
#if N_POINT_LIGHTS
           L +=  Li_lightSampled * bsdf_lightSampled * AbsDot(wiW_lightSampled, isect.nor) / pdf_light;
#endif
        }else if(isLightType == 3){
#if N_SPOT_LIGHTS
           L +=  Li_lightSampled * bsdf_lightSampled * AbsDot(wiW_lightSampled, isect.nor) / pdf_light;
#endif
        }else{
           L +=  Li_lightSampled * bsdf_lightSampled * AbsDot(wiW_lightSampled, isect.nor) / pdf_light;
        }

    }

    vec3 wiW_bsdfSampled;
    vec3 bsdf_bsdfSampled;
    float pdf_bsdf;
    bsdf_bsdfSampled = Sample_f(isect,
                                     -ray.direction,
                                     vec2(rng(), rng()),
                                     wiW_bsdfSampled,
                                     pdf_bsdf,
                                     sampledType);

    if (pdf_bsdf > 0.0 && bsdf_bsdfSampled != vec3(0.)) {

        if (isLightType == 1){
#if N_AREA_LIGHTS
            AreaLight light = areaLights[chosenLightIdx];
            Ray newray = SpawnRay(view_point,
                               wiW_bsdfSampled);
            Intersection nextIsect = sceneIntersect(newray);
            if (nextIsect.obj_ID == light.ID) {
                vec3 Li_bsdfSampled = light.Le ;
                float pdf_light_bsdfSampled = Pdf_Li(view_point,
                                                     isect.nor,
                                                     wiW_bsdfSampled,
                                                     chosenLightIdx);
                float weight_light = PowerHeuristic(1, pdf_bsdf,
                                                    1, pdf_light_bsdfSampled);
                L += weight_light * Li_bsdfSampled * bsdf_bsdfSampled * AbsDot(wiW_bsdfSampled, isect.nor) / pdf_bsdf;
            }
#endif
        }else if (isLightType == 2) {
#if N_POINT_LIGHTS
#endif
        }else if(isLightType == 3){
#if N_SPOT_LIGHTS
#endif
        }else{
        }
    }
    return L;
}

