/* bench.c - small, dependency-free benchmark for OpenWrt routers.
 *
 * Build (static, target musl):
 *   arm-openwrt-linux-muslgnueabi-gcc -static -O2 -pthread -o bench bench.c
 *
 * Usage:
 *   bench cpu [threads]
 *   bench membw [MB]
 *   bench memlat
 *   bench iowrite <path> <MB>
 *   bench ioread <path>
 *
 * Output is CSV: metric,value
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>

static double now(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec + ts.tv_nsec / 1e9;
}

static volatile uint64_t sink;

static void *int_worker(void *arg)
{
	uint64_t n = (uint64_t)(uintptr_t)arg;
	uint64_t x = 0x9e3779b97f4a7c15ULL;
	for (uint64_t i = 0; i < n; i++)
		x = x * 6364136223846793005ULL + 1442695040888963407ULL;
	sink = x;
	return NULL;
}

static void *fp_worker(void *arg)
{
	uint64_t n = (uint64_t)(uintptr_t)arg;
	double a = 1.0000000001;
	for (uint64_t i = 0; i < n; i++)
		a = a * 1.00000000000001 + 1e-15;
	sink = (uint64_t)(a * 1e15);
	return NULL;
}

static int run_cpu(int argc, char **argv)
{
	int threads = (argc > 2) ? atoi(argv[2]) : 1;
	uint64_t per = 300000000ULL;
	pthread_t th[8];
	double t0, dt;
	if (threads < 1) threads = 1;
	if (threads > 8) threads = 8;

	t0 = now();
	for (int i = 0; i < threads; i++)
		pthread_create(&th[i], NULL, int_worker, (void *)(uintptr_t)per);
	for (int i = 0; i < threads; i++)
		pthread_join(th[i], NULL);
	dt = now() - t0;
	printf("cpu_int_%dt_mops,%.2f\n", threads, threads * (double)per / dt / 1e6);

	t0 = now();
	for (int i = 0; i < threads; i++)
		pthread_create(&th[i], NULL, fp_worker, (void *)(uintptr_t)per);
	for (int i = 0; i < threads; i++)
		pthread_join(th[i], NULL);
	dt = now() - t0;
	printf("cpu_fp_%dt_mops,%.2f\n", threads, threads * (double)per / dt / 1e6);
	return 0;
}

static int run_membw(int argc, char **argv)
{
	size_t mb = (argc > 2) ? (size_t)atoi(argv[2]) : 64;
	size_t bytes = mb << 20, n = bytes / 8;
	uint64_t *a, *b;
	double t0, dt;
	int passes = 10;

	if (posix_memalign((void **)&a, 64, bytes) || posix_memalign((void **)&b, 64, bytes)) {
		perror("alloc");
		return 1;
	}
	for (size_t i = 0; i < n; i++) a[i] = i;

	t0 = now();
	for (int p = 0; p < passes; p++) {
		uint64_t s0 = 0, s1 = 0, s2 = 0, s3 = 0;
		size_t i;
		for (i = 0; i + 3 < n; i += 4) {
			s0 += a[i]; s1 += a[i + 1]; s2 += a[i + 2]; s3 += a[i + 3];
		}
		sink = s0 + s1 + s2 + s3;
	}
	dt = now() - t0;
	printf("membw_read_gbs,%.2f\n", (double)passes * bytes / dt / 1e9);

	t0 = now();
	for (int p = 0; p < passes; p++)
		for (size_t i = 0; i < n; i++) a[i] = (uint64_t)i;
	dt = now() - t0;
	printf("membw_write_gbs,%.2f\n", (double)passes * bytes / dt / 1e9);

	t0 = now();
	for (int p = 0; p < passes; p++) {
		memcpy(b, a, bytes);
		/* keep the copy alive and force the write to land */
		sink += b[0] + b[n - 1];
	}
	dt = now() - t0;
	printf("membw_copy_gbs,%.2f\n", (double)passes * bytes / dt / 1e9);

	free(a); free(b);
	return 0;
}

static int run_memlat(void)
{
	size_t sizes[] = { 4 << 10, 64 << 10, 1 << 20, 8 << 20, 32 << 20 };
	uint64_t accesses = 5000000;
	for (size_t k = 0; k < sizeof(sizes) / sizeof(sizes[0]); k++) {
		size_t bytes = sizes[k], n = bytes / 8;
		uint32_t *perm;
		uint64_t *buf;
		uint64_t x = 88172645463325252ULL;
		double t0, dt;
		uint64_t idx = 0;
		if (posix_memalign((void **)&buf, 64, bytes)) return 1;
		perm = malloc(n * sizeof(uint32_t));
		if (!perm) return 1;
		for (size_t i = 0; i < n; i++) { perm[i] = (uint32_t)i; buf[i] = i; }
		for (size_t i = n - 1; i > 0; i--) {
			size_t j;
			x ^= x << 13; x ^= x >> 7; x ^= x << 17;
			j = (size_t)(x % (i + 1));
			uint32_t tmp = perm[i]; perm[i] = perm[j]; perm[j] = tmp;
		}
		t0 = now();
		for (uint64_t i = 0; i < accesses; i++) {
			idx = perm[idx];
			sink += buf[idx];
		}
		dt = now() - t0;
		printf("memlat_%zuk_ns,%.2f\n", bytes >> 10, (dt / accesses) * 1e9);
		free(perm); free(buf);
	}
	return 0;
}

static int run_iowrite(int argc, char **argv)
{
	if (argc < 4) { fprintf(stderr, "usage: iowrite <path> <MB>\n"); return 2; }
	const char *path = argv[2];
	size_t mb = (size_t)atoi(argv[3]);
	size_t blk = 1 << 20;
	char *buf;
	int fd;
	double t0, dt;

	if (posix_memalign((void **)&buf, 4096, blk)) return 1;
	memset(buf, 0x5a, blk);
	fd = open(path, O_CREAT | O_TRUNC | O_WRONLY, 0644);
	if (fd < 0) { perror(path); return 1; }
	t0 = now();
	for (size_t i = 0; i < mb; i++) {
		if (write(fd, buf, blk) != (ssize_t)blk) { perror("write"); close(fd); return 1; }
	}
	fsync(fd);
	dt = now() - t0;
	close(fd);
	printf("iowrite_mbs,%.2f\n", (double)mb / dt);
	free(buf);
	return 0;
}

static int run_ioread(int argc, char **argv)
{
	if (argc < 3) { fprintf(stderr, "usage: ioread <path>\n"); return 2; }
	const char *path = argv[2];
	size_t blk = 1 << 20;
	char *buf;
	int fd;
	double t0, dt;
	ssize_t r;
	size_t total = 0;

	if (posix_memalign((void **)&buf, 4096, blk)) return 1;
	fd = open(path, O_RDONLY);
	if (fd < 0) { perror(path); return 1; }
	posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED);
	t0 = now();
	while ((r = read(fd, buf, blk)) > 0) total += (size_t)r;
	dt = now() - t0;
	close(fd);
	if (dt > 0 && total > 0)
		printf("ioread_mbs,%.2f\n", (double)total / 1048576.0 / dt);
	free(buf);
	return 0;
}

int main(int argc, char **argv)
{
	if (argc < 2) {
		fprintf(stderr, "usage: %s cpu|membw|memlat|iowrite|ioread ...\n", argv[0]);
		return 2;
	}
	if (!strcmp(argv[1], "cpu")) return run_cpu(argc, argv);
	if (!strcmp(argv[1], "membw")) return run_membw(argc, argv);
	if (!strcmp(argv[1], "memlat")) return run_memlat();
	if (!strcmp(argv[1], "iowrite")) return run_iowrite(argc, argv);
	if (!strcmp(argv[1], "ioread")) return run_ioread(argc, argv);
	fprintf(stderr, "unknown mode\n");
	return 2;
}
