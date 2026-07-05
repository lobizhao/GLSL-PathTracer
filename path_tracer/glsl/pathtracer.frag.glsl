
const float FOVY = 19.5f * PI / 180.0;


Ray rayCast() {
    vec2 offset = vec2(rng(), rng());
    vec2 ndc = (vec2(gl_FragCoord.xy) + offset) / vec2(u_ScreenDims);
    ndc = ndc * 2.f - vec2(1.f);

    float aspect = u_ScreenDims.x / u_ScreenDims.y;
    vec3 ref = u_Eye + u_Forward;
    vec3 V = u_Up * tan(FOVY * 0.5);
    vec3 H = u_Right * tan(FOVY * 0.5) * aspect;
    vec3 p = ref + H * ndc.x + V * ndc.y;

    return Ray(u_Eye, normalize(p - u_Eye));
}


// TODO: Implement naive integration
vec3 Li_Naive(Ray ray) {
    vec3 Lo = vec3(0.f);
    vec3 throughput = vec3(1.f);
    for(int i=0; i<MAX_DEPTH; i++){
        Intersection isect = sceneIntersect(ray);

        if(isect.t == INFINITY){
            break;
        }

        if(dot(isect.Le, isect.Le) > 0.f){
            Lo += isect.Le * throughput;
            break;
        }
        vec2 xi = vec2(rng(), rng());
        vec3 wo = -ray.direction;
        vec3 wi;
        float pdf;
        int sampledType;

        vec3 bsdf = Sample_f(isect, wo, xi, wi, pdf, sampledType);
        if(pdf == 0.f){
            break;
        }

        vec3 this_iter_thoughput = bsdf * AbsDot(wi, isect.nor)/pdf;
        throughput *= this_iter_thoughput;
        ray = SpawnRay(ray.origin + isect.t * ray.direction, wi);
    }

    return Lo;
}

// vec3 Li(Ray ray)
// {
//     Intersection isect = sceneIntersect(ray);
//     if(isect.t == INFINITY) {
//         return vec3(0.0);
//     }

//     if(dot(isect.Le, isect.Le) > 0.0) {
//         return isect.Le;
//     }

//     vec3 woW = -ray.direction;
//     float pdf_light;
//     vec3 wiW;
//     vec3 L_dir = Sample_Li(
//         ray.origin + ray.direction * isect.t,
//         isect.nor,
//         wiW, pdf_light
//     );

//     if(pdf_light < 1e-6) {
//         return vec3(0.0);
//     }

//     //bsdf
//     vec3 fVal = f(isect, woW, wiW);
//     float cosTheta = max(0.0, dot(isect.nor, wiW));
//     vec3 Lo = fVal * L_dir * cosTheta / pdf_light;
//     return Lo;
// }


// vec3 Li_DirectMIS(Ray ray) {
//     //FOR ray one
//     vec3 Light_sum = vec3(0.f);
//     Intersection isect = sceneIntersect(ray);

//     if (dot(isect.Le, isect.Le) > 0.f) {
//         return isect.Le;
//     }


//     float pdf;
//     vec3 wiW;
//     vec3 woW = -ray.direction;

//     int chosenLightIdx;
//     int lightID;
//     //sample_li changed!!!!
//     vec3 directLight = Sample_Li(ray.origin + isect.t * ray.direction,
//                                  isect.nor, wiW, pdf,
//                                  chosenLightIdx, lightID);
//     //BSDF
//     vec3 f = f(isect, woW, wiW);

//     Ray testRay = SpawnRay(ray.origin + isect.t * ray.direction, wiW);
//     Intersection testIsect = sceneIntersect(testRay);

//     if (testIsect.t != INFINITY) {
//         if (pdf > 0.f) {
//             float brdfPdf = Pdf(isect, ray.direction, wiW);
//             float weight = PowerHeuristic(1, pdf, 1, brdfPdf);

//             Light_sum += weight*f*directLight*AbsDot(wiW, isect.nor)/pdf;
//         }
//     }

//     //FOR ray two
//     vec2 xi = vec2(rng(), rng());
//     wiW = vec3(0.);
//     pdf = 0.;
//     int sampledType;
//     vec3 f2 = Sample_f(isect, woW, xi, wiW, pdf, sampledType);

//     if(pdf == 0.0f) {
//         return Light_sum;
//     }
//     wiW = normalize(wiW);
//     testRay = SpawnRay(ray.origin + isect.t * ray.direction, wiW);
//     testIsect = sceneIntersect(testRay);

//     float weight2 = 1.f;
//     vec3 light2 = vec3(0.);
//     float lightPdf = Pdf_Li(ray.origin + isect.t * ray.direction, isect.nor, wiW, chosenLightIdx);
//     //if light pdf larger than 0, mis weight
//     if (lightPdf > 0.f) {

//         weight2 = PowerHeuristic(1, pdf, 1, lightPdf);
//         if (testIsect.t != INFINITY) {
//             if (dot(testIsect.Le, testIsect.Le) > 0.f) {
//                 light2 = testIsect.Le;
//             }
//         }
//     }
//     //add bsdf sample
//     Light_sum += weight2*f2*light2*AbsDot(wiW, isect.nor)/pdf;
//     return Light_sum;
// }

vec3 Li_Full(Ray ray) {
    vec3 accum_li = vec3(0.0);
    bool specular = false;
    vec3 throughput = vec3(1.0);
    Intersection isect;
    for(int depth = 0; depth < MAX_DEPTH; ++depth) {

        vec3 wo = -ray.direction;

        vec3 direct_Li = vec3(0.);

        if (isect.material.type == SPEC_REFL ||
            isect.material.type == SPEC_TRANS ||
            isect.material.type == SPEC_GLASS) {
            specular = true;
        }else{

            isect = sceneIntersect(ray);
            direct_Li = ComputeDirectLight_MIS(isect, ray);
            specular = false;
        }

        isect = sceneIntersect(ray);
        if (isect.t == INFINITY) {
            vec2 uv = sampleSphericalMap(ray.direction);
            //add env
            vec3 env_Le = texture(u_EnvironmentMap, uv).rgb;
            accum_li += throughput * env_Le;
            break;
            return vec3(0.);
        }

        if (isect.Le != vec3(0.)) {
            if (specular || depth == 0) {
                return isect.Le * throughput + accum_li;
            }
            return accum_li;
        }

        vec3 wiW;
        float pdf;

        int sampledType;

        vec3 bsdf = Sample_f(isect, -ray.direction, vec2(rng(), rng()), wiW, pdf, sampledType);


        if (pdf > 0.f && bsdf!= vec3(0.)) {
            float lambert = AbsDot(wiW, isect.nor);
            ray = SpawnRay(ray.origin + isect.t * ray.direction, wiW);
            throughput *= bsdf * lambert / pdf;
            accum_li += direct_Li * throughput;
        }else{
            break;
        }

    }

    return accum_li;
}


void main()
{
    seed = uvec2(u_Iterations, u_Iterations + 1) * uvec2(gl_FragCoord.xy);

    Ray ray = rayCast();


    // TODO: Implement Li_Naive
    //vec3 thisIterationColor = Li_Naive(ray);

    //Li hw3 part 2
    //vec3 thisIterationColor = Li(ray);

    //lIDIRECTMIS HW 4
    //vec3 thisIterationColor = Li_DirectMIS(ray);

    //for hw5
    vec3 thisIterationColor = Li_Full(ray);

    // TODO: Set out_Col to the weighted sum of thisIterationColor
    // and all previous iterations' color values.
    // Refer to pathtracer.defines.glsl for what variables you may use
    // to acquire the needed values.

    vec3 lastIterationColor = texelFetch(u_AccumImg, ivec2(gl_FragCoord.xy), 0).rgb;
    if (u_Iterations == 1) {
        out_Col = vec4(thisIterationColor, 1.);
    } else {
        out_Col = vec4(mix(lastIterationColor, thisIterationColor, 1.0 / u_Iterations), 1.0);
    }

}
