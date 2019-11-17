arm-linux-gnueabihf-g++ -march=armv7-a -mfpu=neon-vfpv3 -mtune=cortex-a9 -funsafe-math-optimizations -ftree-vectorize -fPIC main.cpp -o test -L. -ltensorflow-lite -lpthread -Wl,--no-as-needed -ldl

