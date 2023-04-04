# Rocket Chip 修改日志

## 4.4

先安装 [rocket-tools](https://github.com/chipsalliance/rocket-tools)，由于之前已经安装过 riscv-gnu-toolchain ，只能参考脚本手动安装仓库包含的项目：

- [x] riscv-isa-sim：Spike 模拟器
- [x] riscv-tests：RISC-V 处理器的单元测试
- [x] riscv-openocd：硬件调试，目前对这方面不太了解
- [x] riscv-pk：Proxy Kernel，pk 可以执行静态 ELF，提供 bbl 用来引导 RISC-V Linux
- [x] riscv-gnu-toolchain：RISC-V 工具链，需要 riscv-unknown-elf 和 riscv-unknown-linux-gnu

工具链的 submodule 拉取太慢，把里面的部分 url 改成 tuna 镜像源。

最后执行 `tar -zcvf rocket-tools.tar.gz riscv-gnu-toolchain riscv-isa-sim riscv-openocd riscv-pk riscv-tests build.sh` 这样就不需要每次都 clone 了。

勉强安装成功后，Rocket Chip 切到 v1.6 也就是最新的 release 版本， emulator 里尝试 make，报错找不到头文件，查看相关 [issue](https://github.com/chipsalliance/rocket-chip/issues/2766) 发现是 bison 版本过高导致的，然而我的电脑是 Ubuntu 22.04 版本，默认安装的 bison 就是 3.8.2，只能想其他办法。

学习 Docker 构建和开发流程，编写 Dockerfile ，由于仓库拉取比较麻烦，选择先在 clone 到本地，然后在 Dockerfile 中全都 COPY 进去构建，构建脚本 build.sh 来自 rocket-tools 这个官方仓库：

```docker
FROM ubuntu:20.04

# Set tzdata noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update \
    && apt-get install -y git vim wget fish autoconf automake \
    autotools-dev curl libmpc-dev libmpfr-dev \
    libgmp-dev libusb-1.0-0-dev gawk build-essential \
    bison flex texinfo gperf libtool patchutils bc \
    zlib1g-dev device-tree-compiler pkg-config \
    libexpat-dev libfl-dev gnutls-bin \
    openjdk-8-jre openjdk-8-jdk

# RISC-V tools
ENV RISCV=/root/riscv

ENV PATH=$PATH:$RISCV/bin

WORKDIR /root

# Build default tools (pre-cloned and copied from local working directory)
ADD rocket-tools.tar.gz tools
RUN cd tools && chmod +x build.sh && ./build.sh \
    && cd riscv-gnu-toolchain/build \
    && make linux -j $(nproc) \
    && make install

# Clean repos
RUN rm -rf tools

# Install sbt
RUN curl -fL https://github.com/coursier/coursier/releases/latest/download/cs-x86_64-pc-linux.gz \
    | gzip -d > cs && chmod +x cs && ./cs setup -y
```

执行 `docker build -t rocket -f Dockerfile --progress=plain . 2>&1 | tee build.log` 构建镜像，用时一个下午构建成功。执行 `docker image ls -a` 查看当前镜像，需要将该镜像 push 到 Docker Hub。执行 `docker login && docker tag rocket tkf2023/images:v1 && docker push tkf2023/images:v1` 成功将镜像上传至仓库。

Docker 清理：

- ‵docker system prune --volumes`
- `docke` container prune`：删除状态为 exited 的容器
- `docker rm -f $(docker ps -aq)`：删除所有容器
- `docker image ls -f dangling=true`：列出所有镜像（包含中间层、被容器使用的镜像）
- `docker image rm $(docker image ls -f dangling=true)`：删除所有镜像