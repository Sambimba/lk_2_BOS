#include "libmysyslog-json.h"
#include <stdio.h>
#include <time.h>

static const char* log_levels[] = {"DEBUG", "INFO", "WARN", "ERROR", "CRITICAL"};

int log_to_json(const char* msg, int level, const char* path) {
    FILE* file = fopen(path, "a");
    if (!file) return -1;

    time_t now = time(NULL);
    fprintf(file, "{\"timestamp\":%ld,\"log_level\":\"%s\",\"message\":\"%s\"}\n", now, log_levels[level], msg);
    fclose(file);
    return 0;
}
