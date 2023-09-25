FROM mcr.microsoft.com/dotnet/sdk:7.0-jammy-arm64v8 as builder

ENV DEBIAN_FRONTEND=noninteractive
ENV OPENCV_VERSION=4.8.0

WORKDIR /

# Install opencv dependencies
RUN apt-get update && apt-get -y install --no-install-recommends \
    apt-transport-https \
    software-properties-common \
    wget \
    unzip \
    ca-certificates \
    build-essential \
    cmake \
    libtbb-dev \
    libatlas-base-dev \
    libgtk2.0-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libdc1394-dev \
    libxine2-dev \
    libv4l-dev \
    libtheora-dev \
    libvorbis-dev \
    libxvidcore-dev \
    libopencore-amrnb-dev \
    libopencore-amrwb-dev \
    x264 \
    libtesseract-dev \
    libgdiplus \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/*

# Setup opencv and opencv-contrib source
RUN wget -q https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip && \
    unzip -q ${OPENCV_VERSION}.zip && \
    rm ${OPENCV_VERSION}.zip && \
    mv opencv-${OPENCV_VERSION} opencv && \
    wget -q https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip && \
    unzip -q ${OPENCV_VERSION}.zip && \
    rm ${OPENCV_VERSION}.zip && \
    mv opencv_contrib-${OPENCV_VERSION} opencv_contrib



# Build OpenCV
RUN cd opencv && mkdir build && cd build && \
    cmake \
    -D OPENCV_EXTRA_MODULES_PATH=/opencv_contrib/modules \
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D BUILD_SHARED_LIBS=OFF \
    -D ENABLE_CXX11=ON \
    -D BUILD_EXAMPLES=OFF \
    -D BUILD_DOCS=OFF \
    -D BUILD_PERF_TESTS=OFF \
    -D BUILD_TESTS=OFF \
    -D BUILD_JAVA=OFF \
    -D BUILD_opencv_app=OFF \
    -D BUILD_opencv_barcode=OFF \
    -D BUILD_opencv_java_bindings_generator=OFF \
    -D BUILD_opencv_js_bindings_generator=OFF \
    -D BUILD_opencv_python_bindings_generator=OFF \
    -D BUILD_opencv_python_tests=OFF \
    -D BUILD_opencv_ts=OFF \
    -D BUILD_opencv_js=OFF \
    -D BUILD_opencv_bioinspired=OFF \
    -D BUILD_opencv_ccalib=OFF \
    -D BUILD_opencv_datasets=OFF \
    -D BUILD_opencv_dnn_objdetect=OFF \
    -D BUILD_opencv_dpm=OFF \
    -D BUILD_opencv_fuzzy=OFF \
    -D BUILD_opencv_gapi=OFF \
    -D BUILD_opencv_intensity_transform=OFF \
    -D BUILD_opencv_mcc=OFF \
    -D BUILD_opencv_objc_bindings_generator=OFF \
    -D BUILD_opencv_rapid=OFF \
    -D BUILD_opencv_reg=OFF \
    -D BUILD_opencv_stereo=OFF \
    -D BUILD_opencv_structured_light=OFF \
    -D BUILD_opencv_surface_matching=OFF \
    -D BUILD_opencv_videostab=OFF \
    -D BUILD_opencv_wechat_qrcode=ON \
    -D WITH_GSTREAMER=OFF \
    -D WITH_ADE=OFF \
    -D OPENCV_ENABLE_NONFREE=ON \
    .. && make -j$(nproc) && make install && ldconfig

# Download OpenCvSharp

COPY ../../ ./opencvsharp/
RUN cd opencvsharp

# Install the Extern lib.
RUN mkdir /opencvsharp/make && cd /opencvsharp/make && \
    cmake -D CMAKE_INSTALL_PREFIX=/opencvsharp/make /opencvsharp/src && \
    make -j$(nproc) && make install && \
    rm -rf /opencv && \
    rm -rf /opencv_contrib && \
    cp /opencvsharp/make/OpenCvSharpExtern/libOpenCvSharpExtern.so /usr/lib/ && \
    mkdir /artifacts && \
    cp /opencvsharp/make/OpenCvSharpExtern/libOpenCvSharpExtern.so /artifacts/ && cd ..

# COPY --from=builder /usr/lib /usr/lib
# Install Build the C# part of OpenCvSharp
# COPY ../../ ./opencvsharp/
# RUN cd opencvsharp
RUN cd /opencvsharp/src/OpenCvSharp && \
    dotnet build -c Release -f net7.0 && \
    cd /opencvsharp/src/OpenCvSharp.Extensions && \
    dotnet build -c Release -f net7.0

# Install .NET for X64 architecture
RUN wget -q https://download.visualstudio.microsoft.com/download/pr/7190497a-9e02-4369-ba8a-29e7a4acc69e/45af3f104e254cc37cf48227bc8e464c/dotnet-sdk-7.0.401-osx-x64.tar.gz && \
    mkdir -p /usr/share/dotnet/x64 && \
    tar -zxf dotnet-sdk-7.0.401-osx-x64.tar.gz -C /usr/share/dotnet/x64

# Set the path for dotnet
ENV DOTNET_ROOT="/usr/share/dotnet/x64"
# Run the dotnet test command
# RUN ${DOTNET_ROOT}/dotnet test 
RUN ${DOTNET_ROOT}/dotnet test /opencvsharp/test/OpenCvSharp.Tests/OpenCvSharp.Tests.csproj -c Release -f net7.0 --runtime osx-x64 --logger "trx;LogFileName=test-results.trx" 
RUN cp test-results.trx /usr/lib/test-results.trx


# ########## Test native .so file ##########

# FROM mcr.microsoft.com/dotnet/sdk:7.0-jammy as test-native
# RUN apt-get update && apt-get -y install --no-install-recommends gcc
# # /usr/lib/libOpenCvSharpExtern.so
# # /usr/local/lib/libopencv_*.a
# COPY --from=builder /usr/lib /usr/lib
# #COPY --from=builder /usr/local/lib /usr/local/lib
# # RUN mkdir /usr/lib/test && cp /test/ /test/
# RUN echo "\n\
#     #include <stdio.h> \n\
#     int core_Mat_sizeof(); \n\
#     int main(){ \n\
#     int i = core_Mat_sizeof(); \n\
#     printf(\"sizeof(Mat) = %d\", i); \n\
#     return 0; \n\
#     }" > /test.c && \
#     gcc -I./ -L./ test.c -o test -lOpenCvSharpExtern && \
#     LD_LIBRARY_PATH=. ./test 


########## Test .NET class libraries ##########

# FROM mcr.microsoft.com/dotnet/sdk:7.0-jammy as test_image
# COPY --from=builder /usr/lib /usr/lib
# # Install Build the C# part of OpenCvSharp
# COPY ../../ ./opencvsharp/
# RUN cd opencvsharp
# RUN cd /opencvsharp/src/OpenCvSharp && \
#     dotnet build -c Release -f net7.0 && \
#     cd /opencvsharp/src/OpenCvSharp.Extensions && \
#     dotnet build -c Release -f net7.0
# RUN dotnet test /opencvsharp/test/OpenCvSharp.Tests/OpenCvSharp.Tests.csproj -c Release -f net7.0 --runtime ubuntu.22.04-x64 --logger "trx;LogFileName=test-results.trx" 
# RUN cp test-results.trx /usr/lib/test-results.trx

########## Final image ##########
FROM mcr.microsoft.com/dotnet/aspnet:7.0-jammy-arm64v8 as final
COPY --from=builder /usr/lib /usr/lib
COPY --from=builder /artifacts /artifacts
# COPY --from=test_image /usr/lib/test-results.trx /usr/lib/test-resutls.trx





#####################
# FROM mcr.microsoft.com/dotnet/aspnet:7.0-jammy as builder
# ENV DEBIAN_FRONTEND=noninteractive
# ENV OPENCV_VERSION=4.8.0

# WORKDIR /

# # Install opencv dependencies
# RUN apt-get update && apt-get -y install --no-install-recommends \
#     apt-transport-https \
#     software-properties-common \
#     wget \
#     unzip \
#     ca-certificates \
#     build-essential \
#     cmake \
#     libtbb-dev \
#     libatlas-base-dev \
#     libgtk2.0-dev \
#     libavcodec-dev \
#     libavformat-dev \
#     libswscale-dev \
#     libdc1394-dev \
#     libxine2-dev \
#     libv4l-dev \
#     libtheora-dev \
#     libvorbis-dev \
#     libxvidcore-dev \
#     libopencore-amrnb-dev \
#     libopencore-amrwb-dev \
#     x264 \
#     libtesseract-dev \
#     libgdiplus \
#     && apt-get -y clean \
#     && rm -rf /var/lib/apt/lists/*

# # Setup opencv and opencv-contrib source
# RUN wget -q https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip && \
#     unzip -q ${OPENCV_VERSION}.zip && \
#     rm ${OPENCV_VERSION}.zip && \
#     mv opencv-${OPENCV_VERSION} opencv && \
#     wget -q https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip && \
#     unzip -q ${OPENCV_VERSION}.zip && \
#     rm ${OPENCV_VERSION}.zip && \
#     mv opencv_contrib-${OPENCV_VERSION} opencv_contrib

# # Build OpenCV
# RUN cd opencv && mkdir build && cd build && \
#     cmake \
#     -D OPENCV_EXTRA_MODULES_PATH=/opencv_contrib/modules \
#     -D CMAKE_BUILD_TYPE=RELEASE \
#     -D BUILD_SHARED_LIBS=OFF \
#     -D ENABLE_CXX11=ON \
#     -D BUILD_EXAMPLES=OFF \
#     -D BUILD_DOCS=OFF \
#     -D BUILD_PERF_TESTS=OFF \
#     -D BUILD_TESTS=OFF \
#     -D BUILD_JAVA=OFF \
#     -D BUILD_opencv_app=OFF \
#     -D BUILD_opencv_barcode=OFF \
#     -D BUILD_opencv_java_bindings_generator=OFF \
#     -D BUILD_opencv_js_bindings_generator=OFF \
#     -D BUILD_opencv_python_bindings_generator=OFF \
#     -D BUILD_opencv_python_tests=OFF \
#     -D BUILD_opencv_ts=OFF \
#     -D BUILD_opencv_js=OFF \
#     -D BUILD_opencv_bioinspired=OFF \
#     -D BUILD_opencv_ccalib=OFF \
#     -D BUILD_opencv_datasets=OFF \
#     -D BUILD_opencv_dnn_objdetect=OFF \
#     -D BUILD_opencv_dpm=OFF \
#     -D BUILD_opencv_fuzzy=OFF \
#     -D BUILD_opencv_gapi=OFF \
#     -D BUILD_opencv_intensity_transform=OFF \
#     -D BUILD_opencv_mcc=OFF \
#     -D BUILD_opencv_objc_bindings_generator=OFF \
#     -D BUILD_opencv_rapid=OFF \
#     -D BUILD_opencv_reg=OFF \
#     -D BUILD_opencv_stereo=OFF \
#     -D BUILD_opencv_structured_light=OFF \
#     -D BUILD_opencv_surface_matching=OFF \
#     -D BUILD_opencv_videostab=OFF \
#     -D BUILD_opencv_wechat_qrcode=ON \
#     -D WITH_GSTREAMER=OFF \
#     -D WITH_ADE=OFF \
#     -D OPENCV_ENABLE_NONFREE=ON \
#     .. && make -j$(nproc) && make install && ldconfig

# # Download OpenCvSharp

# COPY ../../ ./opencvsharp/
# RUN cd opencvsharp

# # Install the Extern lib.
# RUN mkdir /opencvsharp/make && cd /opencvsharp/make && \
#     cmake -D CMAKE_INSTALL_PREFIX=/opencvsharp/make /opencvsharp/src && \
#     make -j$(nproc) && make install && \
#     rm -rf /opencv && \
#     rm -rf /opencv_contrib && \
#     cp /opencvsharp/make/OpenCvSharpExtern/libOpenCvSharpExtern.so /usr/lib/ && \
#     mkdir /artifacts && \
#     cp /opencvsharp/make/OpenCvSharpExtern/libOpenCvSharpExtern.so /artifacts/ 


# ########## Test .NET class libraries ##########

# FROM mcr.microsoft.com/dotnet/sdk:7.0-jammy AS test_dotnet
# COPY --from=builder /usr/lib /usr/lib
# # Install Build the C# part of OpenCvSharp
# COPY ../../ ./opencvsharp/
# RUN cd opencvsharp
# RUN cd /opencvsharp/src/OpenCvSharp && \
#     dotnet build -c Release -f net7.0 && \
#     cd /opencvsharp/src/OpenCvSharp.Extensions && \
#     dotnet build -c Release -f net7.0
# RUN dotnet test /opencvsharp/test/OpenCvSharp.Tests/OpenCvSharp.Tests.csproj -c Release -f net7.0 --runtime osx-x64 --logger "trx;LogFileName=test-results.trx"

# RUN cp test-results.trx /usr/lib/test-results.trx  
# # # RUN cp test-results.trx /arjun/test-results.trx
# # # RUN  mkdir /arjun && cp arjun /arjun/
# # COPY --from=builder /artifacts /artifacts
# # COPY --from=builder /usr/lib /usr/lib

# ########## Final image ##########

# FROM mcr.microsoft.com/dotnet/aspnet:7.0-jammy as final
# COPY --from=builder /usr/lib /usr/lib
# COPY --from=builder /artifacts /artifacts
# COPY --from=test_dotnet /usr/lib/test-results.trx /usr/lib/test-results.trx