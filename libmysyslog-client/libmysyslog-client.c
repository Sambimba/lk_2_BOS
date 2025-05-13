#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include "libmysyslog.h"

void print_usage(const char* prog_name) {
    printf("Usage: %s -m <message> -l <log_level> -d <driver> -f <format> -p <path>\n", prog_name);
}

int main(int argc, char* argv[]) {
    int opt;
    char* message = NULL;
    int level = INFO;
    int driver = TEXT_DRIVER;
    int format = 0;
    char* path = NULL;

    while ((opt = getopt(argc, argv, "m:l:d:f:p:")) != -1) {
        switch (opt) {
            case 'm':
                message = optarg;
                break;
            case 'l':
                level = atoi(optarg);
                break;
            case 'd':
                driver = atoi(optarg);
                break;
            case 'f':
                format = atoi(optarg);
                break;
            case 'p':
                path = optarg;
                break;
            default:
                print_usage(argv[0]);
                exit(EXIT_FAILURE);
        }
    }

    if (!message || !path) {
        print_usage(argv[0]);
        exit(EXIT_FAILURE);
    }

    if (mysyslog(message, level, driver, format, path) != 0) {
        fprintf(stderr, "Failed to log message\n");
        exit(EXIT_FAILURE);
    }

    return 0;
}
