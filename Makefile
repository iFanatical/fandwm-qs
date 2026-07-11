# dwm - dynamic window manager
# See LICENSE file for copyright and license details.

include config.mk

SRC = drw.c dwm.c util.c
OBJ = ${SRC:.c=.o}

all: ${NAME}

.c.o:
	${CC} -c ${CFLAGS} $<

${OBJ}: config.h config.mk

config.h:
	cp config.def.h $@

${NAME}: ${OBJ}
	${CC} -o $@ ${OBJ} ${LDFLAGS}

clean:
	rm -f ${NAME} ${OBJ} ${NAME}-${VERSION}.tar.gz

dist: clean
	mkdir -p ${NAME}-${VERSION}
	cp -R LICENSE Makefile README config.def.h config.mk\
		dwm.1 drw.h util.h ${SRC} dwm.png transient.c ${NAME}-${VERSION}
	tar -cf ${NAME}-${VERSION}.tar ${NAME}-${VERSION}
	gzip ${NAME}-${VERSION}.tar
	rm -rf ${NAME}-${VERSION}

install: all
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f ${NAME} ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/${NAME}
	# helper scripts for the QuickShell panel; installed on a system PATH so
	# QuickShell finds them regardless of the session's per-user PATH.
	for s in scripts/dwm-qs-*; do \
		cp -f "$$s" ${DESTDIR}${PREFIX}/bin; \
		chmod 755 "${DESTDIR}${PREFIX}/bin/$$(basename $$s)"; \
	done
	mkdir -p ${DESTDIR}${MANPREFIX}/man1
	sed "s/VERSION/${VERSION}/g" < dwm.1 > ${DESTDIR}${MANPREFIX}/man1/${NAME}.1
	chmod 644 ${DESTDIR}${MANPREFIX}/man1/${NAME}.1

uninstall:
	rm -f ${DESTDIR}${PREFIX}/bin/${NAME}\
		${DESTDIR}${PREFIX}/bin/dwm-qs-state\
		${DESTDIR}${PREFIX}/bin/dwm-qs-vpn\
		${DESTDIR}${PREFIX}/bin/dwm-qs-net\
		${DESTDIR}${PREFIX}/bin/dwm-qs-bt\
		${DESTDIR}${PREFIX}/bin/dwm-qs-mem\
		${DESTDIR}${PREFIX}/bin/dwm-qs-kbd\
		${DESTDIR}${PREFIX}/bin/dwm-qs-battery\
		${DESTDIR}${PREFIX}/bin/dwm-qs-dunst\
		${DESTDIR}${MANPREFIX}/man1/${NAME}.1

.PHONY: all clean dist install uninstall
