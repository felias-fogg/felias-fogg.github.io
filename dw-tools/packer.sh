#!/bin/bash
#script for packing the dw-link tools: avr-gdb + dw-gdbserver + dw-gsbserver-util
#usage: call the script in this directory; version will be deduced from dw-gdbserver -V

if [ -f ../binaries/x86_64-apple-darwin/dw-gdbserver ]; then
    VERSION=`../binaries/x86_64-apple-darwin/dw-gdbserver -V`
    VERNUM=`echo $VERSION | cut -d' ' -f 3`
    VERSTR=dw-tools-$VERNUM
    echo "Creating tool packages for version $VERSTR"
else
    echo "No dw-gdbversion binary found"
    exit
fi

for dir in ../binaries/*; do
    if [ -d $dir ]; then
	if  [ -f $dir/avr-gdb -o -f $dir/avr-gdb.exe ]; then
	    if [ -f $dir/dw-gdbserver -o -f $dir/dw-gdbserver.exe ]; then
		if [ -d $dir/dw-gdbserver-util ]; then
		    type=${dir##*/}
		    echo "Packing tools for: $type"
		    rm -rf tools
		    mkdir tools
		    cp -r $dir/* tools/
		    tar -jcv --exclude="*DS_Store" --exclude="*/._*" -f ${VERSTR}_${type}.tar.bz2 tools/
		    cd tools
		    if [ ! -f readme.md ]; then 
			tar -zcv --exclude="*DS_Store" --exclude="*/._*" --exclude="avr-gdb*" -f ../../assets/dw-gdbserver-${type}-${VERNUM}.tar.gz .
		    fi
		    cd ..
		    rm -rf tools
		fi
	    fi
	fi
    fi
done
	


