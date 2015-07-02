
#import "TestHelpers.h"

static uint64_t Benchmarks[10] = {0};


void BenchmarkReentrant(NSUInteger benchmarkNumber, void (^block)(void)) {
    if (block) {
        uint64_t time = dispatch_benchmark(1, block);
        Benchmarks[benchmarkNumber] += time;
    }
}


void BenchmarkReentrantPrintResults(void) {
    for (int i = 0; i < 10; i++) {
        float time = ((float)Benchmarks[i]) / 1000000;
        printf("Benchmark #%d, time is %f milliseconds\n", i, time);
    }
}


void BenchmarkReentrantResetResults(void) {
    memset(&Benchmarks, 0, sizeof(uint64_t) * sizeof(10));
}
