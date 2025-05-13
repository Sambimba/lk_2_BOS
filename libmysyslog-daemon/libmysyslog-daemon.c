#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include "libmysyslog.h"

#define CONFIG_PATH "/etc/mysyslog/mysyslog.cfg"
#define PID_FILE "/run/libmysyslog-daemon.pid"

static volatile int keepRunning = 1;

// Обработчик сигналов для корректного завершения демона
void intHandler(int signo) {
    keepRunning = 0;
}

// Функция для чтения конфигурационного файла
void read_config(const char* path, int* level, int* driver, int* format, char* log_path) {
    FILE* file = fopen(path, "r");
    if (!file) {
        fprintf(stderr, "Failed to open configuration file: %s\n", path);
        exit(EXIT_FAILURE);
    }

    if (fscanf(file, "level=%d\n", level) != 1 ||
        fscanf(file, "driver=%d\n", driver) != 1 ||
        fscanf(file, "format=%d\n", format) != 1 ||
        fscanf(file, "path=%255s\n", log_path) != 1) {
        fprintf(stderr, "Incorrect configuration file format: %s\n", path);
        fclose(file);
        exit(EXIT_FAILURE);
    }

    fclose(file);
}

// Функция для записи PID демона в PID-файл
void write_pid_file(const char* pid_file, pid_t pid) {
    int fd = open(pid_file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd == -1) {
        fprintf(stderr, "Failed to open PID file %s: %s\n", pid_file, strerror(errno));
        exit(EXIT_FAILURE);
    }

    char pid_str[20];
    snprintf(pid_str, sizeof(pid_str), "%d\n", pid);

    if (write(fd, pid_str, strlen(pid_str)) == -1) {
        fprintf(stderr, "Failed to write PID to file %s: %s\n", pid_file, strerror(errno));
        close(fd);
        exit(EXIT_FAILURE);
    }

    close(fd);
}

// Функция для превращения процесса в демона
void daemonize(const char* pid_file) {
    pid_t pid, sid;

    // Первый fork: родительский процесс завершает работу
    pid = fork();
    if (pid < 0) {
        fprintf(stderr, "The first fork didn't work out: %s\n", strerror(errno));
        exit(EXIT_FAILURE);
    }
    if (pid > 0) {
        // Родительский процесс завершает работу
        exit(EXIT_SUCCESS);
    }

    // Создание новой сессии
    sid = setsid();
    if (sid < 0) {
        fprintf(stderr, "setsid failed: %s\n", strerror(errno));
        exit(EXIT_FAILURE);
    }

    // Второй fork: гарантирует, что демон не будет лидером сессии
    pid = fork();
    if (pid < 0) {
        fprintf(stderr, "The second fork failed: %s\n", strerror(errno));
        exit(EXIT_FAILURE);
    }
    if (pid > 0) {
        // Родительский процесс завершает работу
        exit(EXIT_SUCCESS);
    }

    // Установка маски файловых прав
    umask(0);

    // Изменение рабочего каталога на корневой
    if (chdir("/") < 0) {
        fprintf(stderr, "Failed to change the working directory to /: %s\n", strerror(errno));
        exit(EXIT_FAILURE);
    }

    // Закрытие всех открытых файловых дескрипторов
    for (int fd = sysconf(_SC_OPEN_MAX); fd >= 0; fd--) {
        close(fd);
    }

    // Перенаправление стандартных дескрипторов на /dev/null
    open("/dev/null", O_RDONLY); // stdin
    open("/dev/null", O_RDWR);   // stdout
    open("/dev/null", O_RDWR);   // stderr

    // Запись PID в PID-файл
    write_pid_file(pid_file, getpid());
}

int main() {
    // Установка обработчиков сигналов
    signal(SIGINT, intHandler);
    signal(SIGTERM, intHandler);

    // Превращение процесса в демона
    daemonize(PID_FILE);

    int level, driver, format;
    char log_path[256];
    read_config(CONFIG_PATH, &level, &driver, &format, log_path);

    while (keepRunning) {
        mysyslog("Daemon log message", level, driver, format, log_path);
        sleep(5); 
    }
    return 0;
}
