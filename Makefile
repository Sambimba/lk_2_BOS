# Определяем переменные для исходных файлов
LIB_DIR = libmysyslog
CLIENT_DIR = libmysyslog-client
DAEMON_DIR = libmysyslog-daemon
JSON_DIR = libmysyslog-json
TEXT_DIR = libmysyslog-text

LIB_SOURCE = $(LIB_DIR)/libmysyslog.c
JSON_SOURCE = $(JSON_DIR)/libmysyslog-json.c
TEXT_SOURCE = $(TEXT_DIR)/libmysyslog-text.c
CLIENT_SOURCE = $(CLIENT_DIR)/libmysyslog-client.c
DAEMON_SOURCE = $(DAEMON_DIR)/libmysyslog-daemon.c

# Пути для заголовочных файлов
INCLUDE_DIRS = -I$(LIB_DIR) -I$(JSON_DIR) -I$(TEXT_DIR)

# Пути для unit-файла systemd и переменные пакетов
UNIT_FILE = /etc/systemd/system/libmysyslog-daemon.service

version = 1.0
revision = 0
architecture = all

all: build_lib build_apps deb
	@echo "\nСборка завершена. Используйте:\n"
	@echo "  make systemd_unit_file  # Создание systemd unit-файла"
	@echo "  make astra_repo         # Создание локального репозитория"

# Сборка библиотек
build_lib:
	@cc $(LIB_SOURCE) -shared -o $(LIB_DIR)/libmysyslog.so
	@cc $(JSON_SOURCE) -shared -o $(JSON_DIR)/libmysyslog-json.so
	@cc $(TEXT_SOURCE) -shared -o $(TEXT_DIR)/libmysyslog-text.so

# Сборка клиентского приложения и демона
build_apps:
	@cc $(INCLUDE_DIRS) $(CLIENT_SOURCE) -o log_client -L$(LIB_DIR) -lmysyslog
	@cc $(INCLUDE_DIRS) $(DAEMON_SOURCE) -o log_daemon -L$(LIB_DIR) -lmysyslog

# Генерация systemd unit-файла
systemd_unit_file:
	@touch $(UNIT_FILE)
	@chmod 664 $(UNIT_FILE)
	@echo "[Unit]"                                >> $(UNIT_FILE)
	@echo "Description=Daemon for logging with libmysyslog" >> $(UNIT_FILE)
	@echo "[Service]"                            >> $(UNIT_FILE)
	@echo "ExecStart=/usr/local/bin/log_daemon"  >> $(UNIT_FILE)
	@echo "Type=forking"                         >> $(UNIT_FILE)
	@echo "PIDFile=/run/libmysyslog-daemon.pid"  >> $(UNIT_FILE)
	@echo "[Install]"                            >> $(UNIT_FILE)
	@echo "WantedBy=multi-user.target"           >> $(UNIT_FILE)

# Создание пакетов .deb
deb: deb_client deb_daemon deb_lib
	@rm -fr MySyslog_client_${version}-${revision}_${architecture}
	@rm -fr MySyslog_daemon_${version}-${revision}_${architecture}
	@rm -fr MySyslog_library_${version}-${revision}_${architecture}

deb_client:
	@mkdir -p MySyslog_client_${version}-${revision}_${architecture}/DEBIAN
	@touch MySyslog_client_${version}-${revision}_${architecture}/DEBIAN/control

	@echo "Package: mysyslog-client"                           >> MySyslog_client_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Version: $(version)"                                >> MySyslog_client_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Architecture: $(architecture)"                      >> MySyslog_client_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Maintainer: Nik"             			   >> MySyslog_client_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Description: Client for libmysyslog logging system" >> MySyslog_client_${version}-${revision}_${architecture}/DEBIAN/control

	@mkdir -p MySyslog_client_${version}-${revision}_${architecture}/usr/local/bin
	@cp log_client MySyslog_client_${version}-${revision}_${architecture}/usr/local/bin
	@dpkg-deb --root-owner-group --build MySyslog_client_${version}-${revision}_${architecture}

deb_daemon:
	@mkdir -p MySyslog_daemon_${version}-${revision}_${architecture}/DEBIAN
	@touch MySyslog_daemon_${version}-${revision}_${architecture}/DEBIAN/control

	@echo "Package: mysyslog-daemon"                           >> MySyslog_daemon_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Version: $(version)"                                >> MySyslog_daemon_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Architecture: $(architecture)"                      >> MySyslog_daemon_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Maintainer: Nik"             			   >> MySyslog_daemon_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Description: Daemon for libmysyslog logging system" >> MySyslog_daemon_${version}-${revision}_${architecture}/DEBIAN/control

	@mkdir -p MySyslog_daemon_${version}-${revision}_${architecture}/usr/local/bin
	@cp log_daemon MySyslog_daemon_${version}-${revision}_${architecture}/usr/local/bin
	@dpkg-deb --root-owner-group --build MySyslog_daemon_${version}-${revision}_${architecture}

deb_lib:
	@mkdir -p MySyslog_library_${version}-${revision}_${architecture}/DEBIAN
	@touch MySyslog_library_${version}-${revision}_${architecture}/DEBIAN/control

	@echo "Package: libmysyslog"                              >> MySyslog_library_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Version: $(version)"                               >> MySyslog_library_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Architecture: $(architecture)"                     >> MySyslog_library_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Maintainer: Nik"            			  >> MySyslog_library_${version}-${revision}_${architecture}/DEBIAN/control
	@echo "Description: Core library for mysyslog logging"    >> MySyslog_library_${version}-${revision}_${architecture}/DEBIAN/control

	@mkdir -p MySyslog_library_${version}-${revision}_${architecture}/usr/local/lib
	@mkdir -p MySyslog_library_${version}-${revision}_${architecture}/usr/local/include
	@cp $(LIB_DIR)/libmysyslog.so MySyslog_library_${version}-${revision}_${architecture}/usr/local/lib
	@cp $(LIB_DIR)/libmysyslog.h MySyslog_library_${version}-${revision}_${architecture}/usr/local/include
	@dpkg-deb --root-owner-group --build MySyslog_library_${version}-${revision}_${architecture}

# Создание локального репозитория APT
astra_repo:
	@mkdir -p /usr/local/repos
	@cp *.deb /usr/local/repos
	@cd /usr/local/repos && dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
	@echo "deb [trusted=yes] file:/usr/local/repos ./" > /etc/apt/sources.list.d/mysyslog.list
	@sudo apt-get update

# Очистка временных файлов
clean:
	@rm -f $(LIB_DIR)/libmysyslog.so $(JSON_DIR)/libmysyslog-json.so $(TEXT_DIR)/libmysyslog-text.so
	@rm -f log_client log_daemon
	@rm -fr MySyslog_client_${version}-${revision}_${architecture}*
	@rm -fr MySyslog_daemon_${version}-${revision}_${architecture}*
	@rm -fr MySyslog_library_${version}-${revision}_${architecture}*
