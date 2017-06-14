#!/usr/bin/python

import sys
import os
if os.path.exists('/usr/share/pyshared'):
    sys.path.append('/usr/share/pyshared')
import socket
import struct


import array

from netlink import hexdump, parse_attributes, Message, Nested, U8Attr, StrAttr, NulStrAttr, Connection, NETLINK_GENERIC, U32Attr, NLM_F_REQUEST
#from genetlink import Controller, GeNlMessage

NETLINK_ROUTE = 0
RTM_GETDCB = 78
AF_UNSPEC = 0

DCB_CMD_UNDEFINED = 0
DCB_CMD_GSTATE = 1
DCB_CMD_SSTATE = 2
DCB_CMD_PGTX_GCFG = 3
DCB_CMD_PGTX_SCFG = 4
DCB_CMD_PGRX_GCFG = 5
DCB_CMD_PGRX_SCFG = 6
DCB_CMD_PFC_GCFG = 7
DCB_CMD_PFC_SCFG = 8
DCB_CMD_SET_ALL = 9
DCB_CMD_GPERM_HWADDR = 10
DCB_CMD_GCAP = 11
DCB_CMD_GNUMTCS = 12
DCB_CMD_SNUMTCS = 13
DCB_CMD_PFC_GSTATE = 14
DCB_CMD_PFC_SSTATE = 15
DCB_CMD_BCN_GCFG = 16
DCB_CMD_BCN_SCFG = 17
DCB_CMD_GAPP = 18
DCB_CMD_SAPP = 19
DCB_CMD_IEEE_SET = 20
DCB_CMD_IEEE_GET = 21
DCB_CMD_GDCBX = 22
DCB_CMD_SDCBX = 23
DCB_CMD_GFEATCFG = 24
DCB_CMD_SFEATCFG = 25
DCB_CMD_CEE_GET = 26
DCB_CMD_IEEE_DEL = 27

DCB_ATTR_UNDEFINED = 0
DCB_ATTR_IFNAME = 1
DCB_ATTR_STATE = 2
DCB_ATTR_PFC_STATE = 3
DCB_ATTR_PFC_CFG = 4
DCB_ATTR_NUM_TC = 5
DCB_ATTR_PG_CFG = 6
DCB_ATTR_SET_ALL = 7
DCB_ATTR_PERM_HWADDR = 8
DCB_ATTR_CAP = 9
DCB_ATTR_NUMTCS = 10
DCB_ATTR_BCN = 11
DCB_ATTR_APP = 12
DCB_ATTR_IEEE = 13
DCB_ATTR_DCBX = 14
DCB_ATTR_FEATCFG = 15
DCB_ATTR_CEE = 16

DCB_ATTR_IEEE_UNSPEC = 0
DCB_ATTR_IEEE_ETS = 1
DCB_ATTR_IEEE_PFC = 2
DCB_ATTR_IEEE_APP_TABLE = 3
DCB_ATTR_IEEE_PEER_ETS = 4
DCB_ATTR_IEEE_PEER_PFC = 5
DCB_ATTR_IEEE_PEER_APP = 6
DCB_ATTR_IEEE_MAXRATE = 7
DCB_ATTR_IEEE_QCN = 8
DCB_ATTR_IEEE_QCN_STATS = 9
DCB_ATTR_IEEE_TRUST = 10

class DcbnlHdr:
    def __init__(self, len, type):
        self.len = len
        self.type = type
    def _dump(self):
        return struct.pack("BBxx", self.len, self.type)

class DcbNlMessage(Message):
    def __init__(self, type, cmd, attrs=[], flags=0):
        self.type = type
        self.cmd = cmd
        self.attrs = attrs
        Message.__init__(self, type, flags=flags,
                         payload=[DcbnlHdr(len=0, type=self.cmd)]+attrs)

    @staticmethod
    def recv(conn):
        msgs = conn.recv()
        packet = msgs[0].payload

	dcb_family, cmd = struct.unpack("BBxx", packet[:4])

        dcbnlmsg = DcbNlMessage(dcb_family, cmd)
        dcbnlmsg.attrs = parse_attributes(packet[4:])

        return dcbnlmsg

class DcbController:
	def __init__(self, intf):
		self.conn = Connection(NETLINK_ROUTE)
		self.intf = intf

	def check_err(self, m, attr_type):
		if m.attrs[attr_type].u8():
			err = OSError("Netlink error: Bad value. see dmesg.")
                    	raise err

	def __parse_array(self,arr, n):
		lst = []
		for i in range (0, len(arr), n):
			lst.append(arr[i:i+8])
		return lst

	def get_dcb_state(self):
		a = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_GSTATE,
				flags=NLM_F_REQUEST, attrs=[a])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)
		return m.attrs[0].u8()

	def set_dcb_state(self, state):
		a = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		state_attr = U8Attr(DCB_ATTR_STATE, state)
		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_SSTATE,
				flags=NLM_F_REQUEST, attrs=[a, state_attr])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)
		self.check_err(m, DCB_ATTR_STATE)

	def get_dcbx(self):
		a = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_GDCBX,
				flags=NLM_F_REQUEST, attrs=[a])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)
		return m.attrs[DCB_ATTR_DCBX].u8()

	def set_dcbx(self, mode):
		a = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		mode_attr = U8Attr(DCB_ATTR_DCBX , mode)
		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_SDCBX,
				flags=NLM_F_REQUEST, attrs=[a, mode_attr])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)
		self.check_err(m, DCB_ATTR_DCBX)

	def get_ieee_pfc(self):
		a = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_GET,
				flags=NLM_F_REQUEST, attrs=[a])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)

		ieee = m.attrs[DCB_ATTR_IEEE].nested()

		a = array.array('B')
		a.fromstring(ieee[DCB_ATTR_IEEE_PFC].str()[0:])

		return a[1]

	def get_ieee_ets(self):
		a = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_GET,
				flags=NLM_F_REQUEST, attrs=[a])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)

		ieee = m.attrs[DCB_ATTR_IEEE].nested()

		willing, ets_cap, cbs = struct.unpack_from("BBB", ieee[DCB_ATTR_IEEE_ETS].str(), 0)

		a = array.array('B')
		a.fromstring(ieee[DCB_ATTR_IEEE_ETS].str()[3:])

		f = lambda A, n=8: [A[i:i+n] for i in range(0, len(A), n)]

		tc_tc_bw, tc_rx_bw, tc_tsa, prio_tc, tc_reco_bw, tc_reco_tsa, reco_prio_tc = f(a,8)

		return prio_tc, tc_tsa, tc_tc_bw

	def set_ieee_pfc(self, _pfc_en):
		pfc_cap = 8
		mbc = 0
		delay = 0

		requests = array.array('B', '\0' * 64)
		indications = array.array('B', '\0' * 64)

		#netlink packet is 64bit alignment
		pads = array.array('B', '\0' * 3)

		pfc = struct.pack("BBBBB", pfc_cap, _pfc_en, mbc, delay, delay) + (requests + indications + pads).tostring()

		intf = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		ieee_pfc = StrAttr(DCB_ATTR_IEEE_PFC, pfc)
		ieee = Nested(DCB_ATTR_IEEE, [ieee_pfc]);

		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_SET,
				flags=NLM_F_REQUEST, attrs=[intf, ieee])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)
		self.check_err(m, DCB_ATTR_IEEE)

	def set_ieee_ets(self, _prio_tc, _tsa, _tc_bw):
		willing = 0
		ets_cap = 0
		cbs = 0
		tc_rx_bw = array.array('B', '\0' * 8)
		tc_reco_bw = array.array('B', '\0' * 8)
		tc_reco_tsa = array.array('B', '\0' * 8)
		reco_prio_tc = array.array('B', '\0' * 8)

		tc_tc_bw = array.array('B', '\0' * 8)
		tc_tsa = array.array('B', '\0' * 8)
		prio_tc = array.array('B', '\0' * 8)

		for up in range(len(_prio_tc)): prio_tc[up] = _prio_tc[up]
		for tc in range(len(_tsa)): tc_tsa[tc] = _tsa[tc]
		for tc in range(len(_tc_bw)): tc_tc_bw[tc] = _tc_bw[tc]

		ets = struct.pack("BBB", willing, ets_cap, cbs) + (tc_tc_bw + tc_rx_bw +
				tc_tsa + prio_tc + tc_reco_bw + tc_reco_tsa +
				reco_prio_tc).tostring()

		intf = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		ieee_ets = StrAttr(DCB_ATTR_IEEE_ETS, ets)
		ieee = Nested(DCB_ATTR_IEEE, [ieee_ets]);

		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_SET,
				flags=NLM_F_REQUEST, attrs=[intf, ieee])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)
		self.check_err(m, DCB_ATTR_IEEE)

	def get_ieee_trust(self):
		a = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_GET,
				flags=NLM_F_REQUEST, attrs=[a])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)

		ieee_nested = m.attrs[DCB_ATTR_IEEE]

		ieee = m.attrs[DCB_ATTR_IEEE].nested()

                dcb_trust = struct.unpack_from("B", ieee[DCB_ATTR_IEEE_TRUST].str(), 0);

		return dcb_trust[0]

	def set_ieee_trust(self, trust):
		dcb_trust = struct.pack("B", trust)
		intf = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		ieee_maxrate = StrAttr(DCB_ATTR_IEEE_TRUST, dcb_trust)
		ieee = Nested(DCB_ATTR_IEEE, [ieee_maxrate]);

		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_SET,
				flags=NLM_F_REQUEST, attrs=[intf, ieee])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)
		self.check_err(m, DCB_ATTR_IEEE)

	def get_ieee_maxrate(self):
		a = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_GET,
				flags=NLM_F_REQUEST, attrs=[a])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)

		ieee_nested = m.attrs[DCB_ATTR_IEEE]

		ieee = m.attrs[DCB_ATTR_IEEE].nested()

                tc_maxrate = struct.unpack_from("QQQQQQQQ",ieee[DCB_ATTR_IEEE_MAXRATE].str(), 0);

		return tc_maxrate

	def set_ieee_maxrate(self, _tc_maxrate):
                tc_maxrate = struct.pack("QQQQQQQQ",
                        _tc_maxrate[0],
                        _tc_maxrate[1],
                        _tc_maxrate[2],
                        _tc_maxrate[3],
                        _tc_maxrate[4],
                        _tc_maxrate[5],
                        _tc_maxrate[6],
                        _tc_maxrate[7],
                        )

		intf = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		ieee_maxrate = StrAttr(DCB_ATTR_IEEE_MAXRATE, tc_maxrate)
		ieee = Nested(DCB_ATTR_IEEE, [ieee_maxrate]);

		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_SET,
				flags=NLM_F_REQUEST, attrs=[intf, ieee])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)
		self.check_err(m, DCB_ATTR_IEEE)

	def get_ieee_qcn(self):
		a = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_GET,
				 flags=NLM_F_REQUEST, attrs=[a])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)

		ieee = m.attrs[DCB_ATTR_IEEE].nested()

		rpg_enable = array.array('B')
		rpg_enable.fromstring(ieee[DCB_ATTR_IEEE_QCN].str()[:8])
		a = array.array('I')
		a.fromstring(ieee[DCB_ATTR_IEEE_QCN].str()[8:])

		lst_params = self.__parse_array(a,8)

		rppp_max_rps = lst_params[0]
		rpg_time_reset = lst_params[1]
		rpg_byte_reset = lst_params[2]
		rpg_threshold = lst_params[3]
		rpg_max_rate = lst_params[4]
		rpg_ai_rate = lst_params[5]
		rpg_hai_rate = lst_params[6]
		rpg_gd = lst_params[7]
		rpg_min_dec_fac = lst_params[8]
		rpg_min_rate = lst_params[9]
		cndd_state_machine = lst_params[10]

		return rpg_enable, rppp_max_rps, rpg_time_reset, rpg_byte_reset, rpg_threshold, rpg_max_rate, rpg_ai_rate, rpg_hai_rate, rpg_gd, rpg_min_dec_fac, rpg_min_rate, cndd_state_machine

	def get_ieee_qcnstats(self):
		a = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_GET,
				 flags=NLM_F_REQUEST, attrs=[a])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)

		ieee = m.attrs[DCB_ATTR_IEEE].nested()

		rppp_rp_centiseconds = struct.unpack_from("QQQQQQQQ",ieee[DCB_ATTR_IEEE_QCN_STATS].str(), 0);
		a = array.array('I')
		a.fromstring(ieee[DCB_ATTR_IEEE_QCN_STATS].str()[64:])

		lst_statistics = self.__parse_array(a,8)

		rppp_created_rps = lst_statistics[0]
		ignored_cnm = lst_statistics[1]
		estimated_total_rate = lst_statistics[2]
		cnms_handled_successfully = lst_statistics[3]
		min_total_limiters_rate = lst_statistics[4]
		max_total_limiters_rate = lst_statistics[5]

		return rppp_rp_centiseconds, rppp_created_rps, ignored_cnm, estimated_total_rate, cnms_handled_successfully, min_total_limiters_rate, max_total_limiters_rate

	# @_qcn: struct of arrays, each array (_qcn[0], _qcn[1].. etc.) holds the values of a certain qcn parameter for all priorities.
	def set_ieee_qcn(self, _qcn):

		qcn = _qcn[0].tostring() + (_qcn[1] + _qcn[2] + _qcn[3] + _qcn[4] + _qcn[5] + _qcn[6] + _qcn[7] + _qcn[8] + _qcn[9] + _qcn[10] + _qcn[11]).tostring()

		intf = NulStrAttr(DCB_ATTR_IFNAME, self.intf)
		ieee_qcn = StrAttr(DCB_ATTR_IEEE_QCN, qcn)
		ieee = Nested(DCB_ATTR_IEEE, [ieee_qcn]);

		m = DcbNlMessage(type = RTM_GETDCB, cmd = DCB_CMD_IEEE_SET,
				 flags=NLM_F_REQUEST, attrs=[intf, ieee])
		m.send(self.conn)
		m = DcbNlMessage.recv(self.conn)
		self.check_err(m, DCB_ATTR_IEEE)
