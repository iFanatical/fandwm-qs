# dwm-qs-shell - hand-rolled C++/Qt panel replacing the QuickShell config.
# Needs qtbase (widgets, dbus, network), libpulse, libX11.

QTMODS   = Qt6Widgets Qt6Gui Qt6Core Qt6DBus Qt6Network
PKGS     = $(QTMODS) libpulse x11

CXX      ?= g++
MOC      ?= $(shell pkg-config --variable=libexecdir Qt6Core)/moc
CXXFLAGS += -std=c++17 -O2 -Wall -fPIC $(shell pkg-config --cflags $(PKGS))
LDLIBS    = $(shell pkg-config --libs $(PKGS))

MODULES  = widgets popup x11util procutil dwmstate calendar pills panel \
           network bluetooth volume tray traymenu desktopentry launcher ipc
# headers containing Q_OBJECT classes
MOCHDRS  = widgets popup procutil dwmstate calendar pills panel network \
           bluetooth volume tray traymenu desktopentry launcher ipc

OBJ      = $(MODULES:%=%.o) main.o $(MOCHDRS:%=moc_%.o)

all: dwm-qs-shell

dwm-qs-shell: $(OBJ)
	$(CXX) -o $@ $(OBJ) $(LDLIBS)

moc_%.cpp: %.h
	$(MOC) $< -o $@

%.o: %.cpp
	$(CXX) -c $(CXXFLAGS) -o $@ $<

$(OBJ): $(wildcard *.h)

clean:
	rm -f dwm-qs-shell *.o moc_*.cpp

.PHONY: all clean
