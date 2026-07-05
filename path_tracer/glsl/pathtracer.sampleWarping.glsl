
vec3 squareToDiskConcentric(vec2 xi) {
    // TODO
    float a = 2.0f * xi.x - 1.0f;
    float b = 2.0f * xi.y - 1.0f;

    float r, theta;

    if (a == 0 && b == 0)
    {
        return vec3(0.f, 0.f, 0.f);
    }

    if (abs(a) > abs(b))
    {
        r = a;
        theta = (PI / 4.0f) * (b / a);
    }
    else
    {
        r = b;
        theta = (PI / 2.0f) - (PI / 4.0f) * (a / b);
    }
    //return vec3(0.);
    return vec3(r * cos(theta), r * sin(theta), 0.0f);
}

vec3 squareToHemisphereCosine(vec2 xi) {
    // TODO
    vec3 diskSample = squareToDiskConcentric(xi);
    float z = sqrt(max(0.0f, 1.0f - diskSample.x * diskSample.x - diskSample.y * diskSample.y));

    return vec3(diskSample.x, diskSample.y, z);
    //return vec3(0.);
}

float squareToHemisphereCosinePDF(vec3 sample) {
    // TODO
    //return 0.f;
    return sample.z / PI;

}

vec3 squareToSphereUniform(vec2 sample) {
    // TODO
    float z= 1- 2*sample.x;
    float x= cos(sample.y*PI*2)*sqrt(1-z*z);
    float y= sin(sample.y*PI*2)*sqrt(1-z*z);
    return vec3(x,y,z);
}

float squareToSphereUniformPDF(vec3 sample) {
    // TODO
    //return 0.f;
    return 1/(4*PI);
}
