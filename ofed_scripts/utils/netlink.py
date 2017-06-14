'''
Netlink message generation/parsing

Copyright 2007        Johannes Berg <johannes@sipsolutions.net>

GPLv2+; See copying for details.
'''

import os
import socket
import struct

def hexdump(msg, data):
	arr=""
	for i in range(len(data)):
		if (i and i % 16 == 0):
			arr +="\n"
		arr += '%02x ' % ord(data[i])
#	hex = lambda data: ' '.join('{:02X}'.format(data[i]) for i in range(len(data)))
	print msg, ":"
	print arr


try:
    # try to use python 2.5's netlink support
    _dummysock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, 0)
    _dummysock.bind((0, 0))
    del _dummysock
    def _nl_bind(descriptor, addr):
        descriptor.bind(addr)
    def _nl_getsockname(descriptor):
        return descriptor.getsockname()
    def _nl_send(descriptor, msg):
        descriptor.send(msg)
    def _nl_recv(descriptor, bufs=16384):
        return descriptor.recvfrom(bufs)
except socket.error:
    # or fall back to the _netlink C module
    try:
        import _netlink
        def _nl_bind(descriptor, addr):
            _netlink.bind(descriptor.fileno(), addr[1])
        def _nl_getsockname(descriptor):
            return _netlink.getsockname(descriptor.fileno())
        def _nl_send(descriptor, msg):
            _netlink.send(descriptor.fileno(), msg)
        def _nl_recv(descriptor, bufs=16384):
            return _netlink.recvfrom(descriptor.fileno(), bufs)
    except ImportError:
        # or fall back to the ctypes module
        import ctypes

        libc = ctypes.CDLL(None)

        class SOCKADDR_NL(ctypes.Structure):
            _fields_ = [("nl_family", ctypes.c_ushort),
                        ("nl_pad",    ctypes.c_ushort),
                        ("nl_pid",    ctypes.c_int),
                        ("nl_groups", ctypes.c_int)]

        def _nl_bind(descriptor, addr):
            addr = SOCKADDR_NL(socket.AF_NETLINK, 0, os.getpid(), 0)
            return libc.bind(descriptor.fileno(),
                             ctypes.pointer(addr),
                             ctypes.sizeof(addr))

        def _nl_getsockname(descriptor):
            addr = SOCKADDR_NL(0, 0, 0, 0)
            len = ctypes.c_int(ctypes.sizeof(addr));
            libc.getsockname(descriptor.fileno(),
                             ctypes.pointer(addr),
                             ctypes.pointer(len))
            return addr.nl_pid, addr.nl_groups;

        def _nl_send(descriptor, msg):
            return libc.send(descriptor.fileno(), msg, len(msg), 0);

        def _nl_recv(descriptor, bufs=16384):
            addr = SOCKADDR_NL(0, 0, 0, 0)
            len = ctypes.c_int(ctypes.sizeof(addr))
            buf = ctypes.create_string_buffer(bufs)

            r = libc.recvfrom(descriptor.fileno(),
                              buf, bufs, 0,
                              ctypes.pointer(addr), ctypes.pointer(len))

            ret = ctypes.string_at(ctypes.pointer(buf), r)
            return ret, (addr.nl_pid, addr.nl_groups)


# flags
NLM_F_REQUEST  = 1
NLM_F_MULTI    = 2
NLM_F_ACK      = 4
NLM_F_ECHO     = 8

NLM_F_ROOT = 0x100
NLM_F_MATCH = 0x200
NLM_F_ATOMIC = 0x400
NLM_F_DUMP = (NLM_F_ROOT | NLM_F_MATCH) + 5

# types
NLMSG_NOOP     = 1
NLMSG_ERROR    = 2
NLMSG_DONE     = 3
NLMSG_OVERRUN  = 4
NLMSG_MIN_TYPE = 0x10

class Attr:
    def __init__(self, attr_type, data, *values):
        self.type = attr_type
        if len(values):
            self.data = struct.pack(data, *values)
        else:
            self.data = data

    def _dump(self):
        hdr = struct.pack("HH", len(self.data)+4, self.type)
        length = len(self.data)
        pad = ((length + 4 - 1) & ~3 ) - length
        return hdr + self.data + '\0' * pad

    def __repr__(self):
        return '<Attr type %d, data "%s">' % (self.type, repr(self.data))

    def u8(self):
        return struct.unpack('B', self.data)[0]
    def u16(self):
        return struct.unpack('H', self.data)[0]
    def s16(self):
        return struct.unpack('h', self.data)[0]
    def u32(self):
        return struct.unpack('I', self.data)[0]
    def s32(self):
        return struct.unpack('i', self.data)[0]
    def str(self):
        return self.data
    def nulstr(self):
        return self.data.split('\0')[0]
    def nested(self):
        return parse_attributes(self.data)

class StrAttr(Attr):
    def __init__(self, attr_type, data):
        Attr.__init__(self, attr_type, "%ds" % len(data), data)

class NulStrAttr(Attr):
    def __init__(self, attr_type, data):
        Attr.__init__(self, attr_type, "%dsB" % len(data), data, 0)

class U32Attr(Attr):
    def __init__(self, attr_type, val):
        Attr.__init__(self, attr_type, "I", val)

class U8Attr(Attr):
    def __init__(self, attr_type, val):
        Attr.__init__(self, attr_type, "B", val)

class Nested(Attr):
    def __init__(self, attr_type, attrs):
        self.attrs = attrs
        self.type = attr_type

    def _dump(self):
        contents = []
        for attr in self.attrs:
            contents.append(attr._dump())
        contents = ''.join(contents)
        length = len(contents)
        hdr = struct.pack("HH", length+4, self.type)
        return hdr + contents

NETLINK_ROUTE          = 0
NETLINK_UNUSED         = 1
NETLINK_USERSOCK       = 2
NETLINK_FIREWALL       = 3
NETLINK_INET_DIAG      = 4
NETLINK_NFLOG          = 5
NETLINK_XFRM           = 6
NETLINK_SELINUX        = 7
NETLINK_ISCSI          = 8
NETLINK_AUDIT          = 9
NETLINK_FIB_LOOKUP     = 10
NETLINK_CONNECTOR      = 11
NETLINK_NETFILTER      = 12
NETLINK_IP6_FW         = 13
NETLINK_DNRTMSG        = 14
NETLINK_KOBJECT_UEVENT = 15
NETLINK_GENERIC        = 16

class Message:
    def __init__(self, msg_type, flags=0, seq=-1, payload=None):
        self.type = msg_type
        self.flags = flags
        self.seq = seq
        self.pid = -1
        payload = payload or []
        if isinstance(payload, list):
            contents = []
            for attr in payload:
                contents.append(attr._dump())
            self.payload = ''.join(contents)
        else:
            self.payload = payload

    def send(self, conn):
        if self.seq == -1:
            self.seq = conn.seq()

        self.pid = conn.pid
        length = len(self.payload)

        hdr = struct.pack("IHHII", length + 4*4, self.type,
                          self.flags, self.seq, self.pid)

        conn.send(hdr + self.payload)

    def __repr__(self):
        return '<netlink.Message type=%d, pid=%d, seq=%d, flags=0x%x "%s">' % (
            self.type, self.pid, self.seq, self.flags, repr(self.payload))

class Connection:
    def __init__(self, nltype, groups=0, unexpected_msg_handler=None):
        self.descriptor = socket.socket(socket.AF_NETLINK,
                                        socket.SOCK_RAW, nltype)
        self.descriptor.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 65536)
        self.descriptor.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
        _nl_bind(self.descriptor, (os.getpid(), groups))
        self.pid, self.groups = _nl_getsockname(self.descriptor)
        self._seq = 0
        self.unexpected = unexpected_msg_handler
    def send(self, msg):
        _nl_send(self.descriptor, msg)
    def recv(self):
        msgs = []
        offset = 0
        contents, (nlpid, nlgrps) = _nl_recv(self.descriptor)
        # XXX: python doesn't give us message flags, check
        #      len(contents) vs. msglen for TRUNC
        while (offset < len(contents)) :
            msglen, msg_type, flags, seq, pid = struct.unpack("IHHII", contents[offset:offset + 16])

            msg = Message(msg_type, flags, seq, contents[offset + 16:offset + msglen])
            msg.pid = pid
            if msg.type == NLMSG_ERROR:
                errno = -struct.unpack("i", msg.payload[:4])[0]
                if errno != 0:
                    err = OSError("Netlink error: %s (%d)" % (os.strerror(errno), errno))
                    err.errno = errno
                    raise err
            msgs.append(msg)
            offset += msglen
        return msgs

    def seq(self):
        self._seq += 1
        return self._seq

def parse_attributes(data):
    attrs = {}
    while len(data):
        attr_len, attr_type = struct.unpack("HH", data[:4])
        attrs[attr_type] = Attr(attr_type, data[4:attr_len])
        attr_len = ((attr_len + 4 - 1) & ~3 )
        data = data[attr_len:]
    return attrs
