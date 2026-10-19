ARG ONEAPI_VERSION=2026.1.1-devel-ubuntu24.04
FROM docker.io/intel/oneapi-toolkit:$ONEAPI_VERSION

SHELL ["/bin/bash", "-c"]

# Install build utilities and Intel Level Zero driver
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        cmake \
        build-essential \
        intel-level-zero-gpu \
   		clinfo \
        intel-opencl-icd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

####### PRISM ML ############
WORKDIR /git
ARG CACHE_BUST_PRISM=1
RUN git clone --depth 1 https://github.com/PrismML-Eng/llama.cpp.git .
RUN cmake -B build \
 	    -DGGML_NATIVE=ON \
	    -DGGML_SYCL=ON \
	    -DGGML_SYCL_F16=ON \
	    -DCMAKE_C_COMPILER=icx \
	    -DCMAKE_CXX_COMPILER=icpx \
	    -DGGML_BACKEND_DL=OFF \
	    -DLLAMA_BUILD_TESTS=OFF \
	    -DCMAKE_INSTALL_PREFIX=/app/llama-sycl-prism \
	    -DCMAKE_INSTALL_RPATH="\$ORIGIN/../lib" && \
	cmake --build build --config Release -j$(nproc) && \
	cmake --install build
RUN rm -rf /git
############################


###### TORCHIT1 ############
WORKDIR /git
ARG CACHE_BUST_TORCHIT=1
RUN git clone --depth 1 https://github.com/Torchit1/llama.cpp.git .
RUN cmake -B build \
		-DGGML_BACKEND_DL=OFF \
 	    -DGGML_NATIVE=ON \
		-DGGML_SYCL=ON \
		-DGGML_SYCL_FP16=ON \
		-DCMAKE_C_COMPILER=icx \
		-DCMAKE_CXX_COMPILER=icpx \
	    -DCMAKE_BUILD_TYPE=Release \
	    -DGGML_SYCL_TARGET=INTEL \
	    -DCMAKE_INSTALL_PREFIX=/app/llama-sycl-torchit1\
	    -DCMAKE_INSTALL_RPATH="\$ORIGIN/../lib" && \
	cmake --build build -j$(nproc) && \
	cmake --install build
RUN rm -rf /git
#########################

# Official ggml llama cpp sycl fp16 release binaries
ARG CACHE_BUST_GGML=1
RUN GGML_TAG=$(curl -s "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=1" \
		| grep -oP '"tag_name":\s*"b\d+"' \
		| head -1 \
		| sed 's/.*"\(b[0-9]*\)".*/\1/') && \
	GGML_URL=$(curl -s "https://api.github.com/repos/ggml-org/llama.cpp/releases#release-$GGML_TAG" \
		| grep "browser_download_url.*ubuntu-sycl-fp16-x64.tar.gz" \
		| head -n 1 | cut -d '"' -f 4) && \
	curl -L -o /tmp/llama-sycl.tar.gz "$GGML_URL" && \
	mkdir /app/llama-sycl && \
	tar -xzf /tmp/llama-sycl.tar.gz -C /app/llama-sycl --strip-components=1 && \
	rm /tmp/llama-sycl.tar.gz

# llama swap latest binaries
ARG CACHE_BUST_SWAP=1
RUN SWAP_URL=$(curl -s https://api.github.com/repos/mostlygeek/llama-swap/releases/latest \
		| grep "browser_download_url.*linux_amd64.tar.gz" \
		| head -n 1 | cut -d '"' -f 4) && \
    curl -L -o /tmp/llama-swap.tar.gz "$SWAP_URL" && \
    tar -xzf /tmp/llama-swap.tar.gz -C /app llama-swap && \
    chmod +x /app/llama-swap && \
    rm /tmp/llama-swap.tar.gz

# Environment configuration
ENV ONEAPI_DEVICE_SELECTOR=level_zero:gpu
ENV GGML_SYCL_PTQ1_T2=all
ENV LLAMA_ARG_SPEC_DRAFT_UBATCH=512
ENV GGML_SYCL_FA_ONEDNN_MAX_KV=98304
ENV GGML_SYCL_FA_DEC_DPAS=1
ENV GGML_SYCL_T2_W8A8_MIN=1024
ENV GGML_SYCL_MMVQ_CHUNK_MAX=128
ENV GGML_SYCL_Q4_0_DPAS=1


WORKDIR /app
ENTRYPOINT ["/app/llama-swap"]
