FROM debian:jessie
MAINTAINER mathias.baumann@gmail.com

# Install all needed tools
RUN apt-get update -qqy && apt-get -qqy install \
    apache2 \
    autoconf \
    libtool \
    curl \
    wget \
    gettext \
    openssh-server \
    python-pip \
    git \
    git-core \
    build-essential \
    cdbs \
    debhelper \
    libusb-1.0-0-dev \
    pkg-config \
    libsystemd-daemon-dev \
    dh-systemd \
    dialog \
    python3 \
    python3-dev \
    python3-setuptools \
    python3-pip \
    unzip \
    libawl-php \
    php5-curl \
    php5 \
    php5-json \
    vim \
    && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

RUN easy_install3 -U pip
# RUN adduser smarthome --disabled-password --gecos "First Last,RoomNumber,WorkPhone,HomePhone"
# RUN usermod -aG www-data smarthome

WORKDIR /opt
RUN wget https://www.auto.tuwien.ac.at/~mkoegler/pth/pthsem_2.0.8.tar.gz && \
    tar xzf pthsem_2.0.8.tar.gz && \
    rm pthsem_2.0.8.tar.gz

# pthsem
WORKDIR /opt/pthsem-2.0.8
RUN dpkg-buildpackage -b -uc
WORKDIR /opt
RUN dpkg -i libpthsem*.deb

# knxd
RUN git clone https://github.com/knxd/knxd.git
WORKDIR /opt/knxd
RUN git pull
RUN dpkg-buildpackage -b -uc
WORKDIR /opt
RUN dpkg -i knxd_*.deb knxd-tools_*.deb
# RUN systemctl enable knxd.service
# RUN systemctl enable knxd.socket

WORKDIR /opt
RUN git clone --recursive git://github.com/smarthomeNG/smarthome.git
# RUN chown -R smarthome:smarthome /opt/smarthome
WORKDIR /opt/smarthome/etc
RUN touch logic.conf

RUN echo "# smarthome.conf \n\
lat = 52.52 \n\
lon = 13.40 \n\
elev = 36 \n\
tz = 'Europe/Berlin'" > smarthome.conf

WORKDIR /opt/smarthome
RUN pip install -r requirements_all.txt

RUN echo "# plugin.conf \n\

\# Der BackendServer stellt eine Übersicht zur Laufzeit dar und liefert Informationen ähnlich wie das CLI Plugin \n\
\# Der Zugriff erfolgt über http://<IP oder Name des SmartHomeNG Servers bzw. ip>:<port> \n\
\# port wird als Attribut weiter unten definiert \n\
\# das Passwort ist zunächst im Klartext anzugeben. In neueren Versionen wird es eine Funktion im Backend geben, \n\
\# die aus einem gegebenen Passwort einen Hash erzeugt. Wenn user oder password fehlen gibt es keine Abfrage \n\
[BackendServer] \n\
    class_name = BackendServer \n\
    class_path = plugins.backend \n\
    \#ip = xxx.xxx.xxx.xxx \n\
    port = 8383 \n\
    updates_allowed = True \n\
    threads = 8 \n\
    user = admin \n\
    password = xxxx \n\
    language = de \n\
\n\
[knx] \n\
   class_name = KNX \n\
   class_path = plugins.knx \n\
   host = 127.0.0.1 \n\
   port = 6720 \n\
\#   send_time = 600 # update date/time every 600 seconds, default none \n\
\#   time_ga = 1/1/1 # default none \n\
\#   date_ga = 1/1/2 # default none \n\
\n\
\# Bereitstellung eines Websockets zur Kommunikation zwischen SmartVISU und SmartHomeNG \n\
[visu] \n\
    class_name = WebSocket \n\
    class_path = plugins.visu_websocket \n\
\#    ip = 0.0.0.0 \n\
\#    port = 2424 \n\
\#    tls = no \n\
    wsproto = 4 \n\
    acl = rw \n\
\n\
\# Autogenerierung von Webseiten für SmartVISU \n\
[smartvisu] \n\
    class_name = SmartVisu \n\
    class_path = plugins.visu_smartvisu \n\
#   "neue" Linux Versionen (z.B. Debian Jessie 8.x, Ubuntu > 14.x) \n\
    smartvisu_dir = /var/www/html/smartVISU \n\
#    nur "alte" Linux-Variationen \n\
#    smartvisu_dir = /var/www/smartVISU \n\
#    generate_pages = True \n\
#    handle_widgets = True \n\
#    overwrite_templates = Yes \n\
#    visu_style = blk \n\
\n\
\# Command Line Interface \n\
\# wichtig für Funktionsprüfungen solange keine Visu zur Verfügung steht \n\
[cli]\n\
    class_name = CLI \n\
    class_path = plugins.cli \n\
    ip = 0.0.0.0 \n\
    update = True \n\
\n\
\# alter SQL-Treiber \n\
\#[sql] \n\
\#    class_name = SQL \n\
\#    class_path = plugins.sqlite \n\
\n\
\#SQL-Treiber, unterstützt auch die SmartVISU 2.8/2.9 \n\
\# dazu muß im websocket plugin zwingend die Protokollversion 4 eingetragen sein \n\
[sql] \n\
    class_name = SQL \n\
    class_path = plugins.sqlite_visu2_8 \n\

\# Onewire Plugin \n\
[ow] \n\
    class_name = OneWire \n\
    class_path = plugins.onewire \n\
" > /opt/smarthome/etc/plugin.conf

RUN echo "\n\
[Unit] \n\
Description=SmartHomeNG daemon \n\
After=network.target \n\
\n\
[Service] \n\
Type=forking \n\
ExecStart=/usr/bin/python3 /opt/smarthome/bin/smarthome.py \n\
User=smarthome \n\
PIDFile=/opt/smarthome/var/run/smarthome.pid \n\
Restart=on-abort \n\
\n\
[Install] \n\
WantedBy=default.target \n\
" > /lib/systemd/system/smarthome.service

# RUN systemctl enable smarthome.service

# smartvisu
WORKDIR /var/www/html
RUN rm index.html
RUN wget http://smartvisu.de/download/smartVISU_2.8.zip
RUN unzip smartVISU_2.8.zip
RUN rm smartVISU_2.8.zip

RUN chown -R www-data:www-data smartVISU
RUN chmod -R 775 smartVISU

RUN apache2ctl start
EXPOSE 80 2424 6720 8383
HEALTHCHECK CMD curl -f http://localhost:2424/ || exit 1
# CMD /opt/smarthome/bin/smarthome.py
