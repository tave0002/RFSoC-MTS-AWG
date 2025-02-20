# -------------------------------------------------------------------------------------------------
# Copyright (C) 2023 Advanced Micro Devices, Inc
# SPDX-License-Identifier: MIT
# ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --
import pynq
from pynq import Overlay, MMIO
import xrfclk
import xrfdc
import numpy as np
import time
import os
import subprocess

MODULE_PATH = os.path.dirname(os.path.realpath(__file__))
CLOCKWIZARD_LOCK_ADDRESS = 0x0004
CLOCKWIZARD_RESET_ADDRESS = 0x0000
CLOCKWIZARD_RESET_TOKEN = 0x000A
MTS_START_TILE = 0x01 #not touching the naming since I don't want to stuff it up
MAX_DAC_TILES = 4
MAX_ADC_TILES = 4
DAC_REF_TILE = 2
ADC_REF_TILE = 2
DEVICETREE_OVERLAY_FOR_PLDRAM = 'ddr4.dtbo'

RFSOC4X2_LMK_FREQ = 500.0
RFSOC4X2_LMX_FREQ = 500.0
RFSOC4X2_DAC_TILES = 0b0101
RFSOC4X2_ADC_TILES = 0b0101

ZCU208_LMK_FREQ = 500.0
ZCU208_LMX_FREQ = 4000.0
ZCU208_DAC_TILES = 0b0011
ZCU208_ADC_TILES = 0b0011

class awgOverlay(Overlay):
    """
    The awg overlay demonstrates the RFSoC ability to act as an arbitrary waveform generator over large bandwidths.
    """
    def __init__(self, bitfile_name='awgStable.bit',version="stable", **kwargs):
        """
         This overlay class supports the AWG overlay.  It configures the PL gpio, internal memories,
         PL-DRAM, and DAC players. Additional helper methods are provided to: configure and verify
         AWG, round frequencies to fit in the internal memory. 
         This can be used either to work with the stable or development version of the overlay
        """
        board = os.getenv('BOARD') 
        # Run lsmod command to get the loaded modules list
        output = subprocess.check_output(['lsmod'])
        # Check if "zocl" is present in the output
        self.stableFlag=1
        if version=="stable":
            self.stableFlag=1
        elif version=="dev":
            self.stableFlag==0
        else:
            assert False, "version spesified isn't an option. Please use 'stable' for functional version or 'dev' for DDR4 testing"
        
        if b'zocl' in output:
            # If present, remove the module using rmmod command
            rmmod_output = subprocess.run(['rmmod', 'zocl'])
            # Check return code
            assert rmmod_output.returncode == 0, "Could not restart zocl. Please Shutdown All Kernels and then restart"
            # If successful, load the module using modprobe command
            modprobe_output = subprocess.run(['modprobe', 'zocl'])
            assert modprobe_output.returncode == 0, "Could not restart zocl. It did not restart as expected"
        else:
            modprobe_output = subprocess.run(['modprobe', 'zocl'])
            # Check return code
            assert modprobe_output.returncode == 0, "Could not restart ZOCL!"

        dts = pynq.DeviceTreeSegment(resolve_binary_path(DEVICETREE_OVERLAY_FOR_PLDRAM))
        if not dts.is_dtbo_applied():
            dts.insert()
        # must configure clock synthesizers 
        # the LMK04828 PL_CLK and PL_SYSREF clocks
        if board == 'RFSoC4x2':
            xrfclk.set_ref_clks(lmk_freq = RFSOC4X2_LMK_FREQ, lmx_freq = RFSOC4X2_LMX_FREQ)
            self.ACTIVE_DAC_TILES = RFSOC4X2_DAC_TILES
            self.ACTIVE_ADC_TILES = RFSOC4X2_ADC_TILES
        elif board == 'ZCU208':
            xrfclk.set_ref_clks(lmk_freq = ZCU208_LMK_FREQ, lmx_freq = ZCU208_LMX_FREQ)
            self.ACTIVE_DAC_TILES = ZCU208_DAC_TILES
            self.ACTIVE_ADC_TILES = ZCU208_ADC_TILES
        else:
            assert False, "Board Not Supported"
        time.sleep(0.5)        
        super().__init__(resolve_binary_path(bitfile_name), **kwargs)
        self.xrfdc = self.usp_rf_data_converter_1       
        #not touching the naming here since I think it'll stuff it up
        self.xrfdc.mts_dac_config.RefTile = DAC_REF_TILE  # DAC tile distributing reference clock
        self.xrfdc.mts_adc_config.RefTile = ADC_REF_TILE  # ADC                

        # map PL GPIO registers
        self.dac_enable =  self.gpio_control.axi_gpio_dac.channel1[0]       
        self.trig_cap = self.gpio_control.axi_gpio_bram_adc.channel1[0]
        self.fifo_flush = self.gpio_control.axi_gpio_fifoflush.channel1[0]
        
        if self.stableFlag==1:
            # DAC Player Memory - DACs will play this waveform
            self.dac_player = self.memdict_to_view("hier_dac_play/axi_bram_ctrl_0")
            self.dac_player2 = self.memdict_to_view("hier_dac_play1/axi_bram_ctrl_0")
    
            # DAC Capture Memory - to verify DAC AWG for diagnostics
            #self.dac_capture = self.memdict_to_view("hier_dac_cap/axi_bram_ctrl_0")

            # ADC Capture Memories
            #self.adc_capture_chA = self.memdict_to_view("hier_adc0_cap/axi_bram_ctrl_0")
            #self.adc_capture_chB = self.memdict_to_view("hier_adc1_cap/axi_bram_ctrl_0") 
            #self.adc_dma = self.deepCapture.axi_dma_adc # PL DMA to DDR4 memory
            #self.ADCdeepcapture = self.memdict_to_view("ddr4_0")       
        
        # Reset GPIOs and bring to known state
        self.dac_enable.off()
        self.trig_cap.off() 
        self.fifo_flush.off() # active low flush of the DMA fifo

    def memdict_to_view(self, ip, dtype='int16'):
        """ Configures access to internal memory via MMIO"""
        baseAddress = self.mem_dict[ip]["phys_addr"]
        mem_range = self.mem_dict[ip]["addr_range"]
        ipmmio = MMIO(baseAddress, mem_range)
        return ipmmio.array[0:ipmmio.length].view(dtype)

    def sync_tiles(self, dacTarget=-1, adcTarget=-1):
        # Set which RF tiles use MTS and turn MTS off
        return "NO ADCs in stable or dev version"
        """if self.stableFlag==0:
            return "Cannot sync tiles in dev version"
        if self.ACTIVE_DAC_TILES > 0:
            self.xrfdc.mts_dac_config.Tiles = self.ACTIVE_DAC_TILES # group defined in binary 0b1111
            self.xrfdc.mts_dac_config.SysRef_Enable = 1
            self.xrfdc.mts_dac_config.Target_Latency = dacTarget 
            self.xrfdc.mts_dac()
        else:
            self.xrfdc.mts_dac_config.Tiles = 0x0
            self.xrfdc.mts_dac_config.SysRef_Enable = 0
        if self.ACTIVE_ADC_TILES > 0:
            self.xrfdc.mts_adc_config.Tiles = self.ACTIVE_ADC_TILES
            self.xrfdc.mts_adc_config.SysRef_Enable = 1
            self.xrfdc.mts_adc_config.Target_Latency = adcTarget
            self.xrfdc.mts_adc()
        else:
            self.xrfdc.mts_adc_config.Tiles = 0x0
            self.xrfdc.mts_adc_config.SysRef_Enable = 0"""

    def init_tile_sync(self):
        """ Resets the MTS alignment engine"""
        return "No ADCs in stable or dev version"
        """self.xrfdc.mts_dac_config.Tiles = 0b0001 # turn only one tile on first
        self.xrfdc.mts_adc_config.Tiles = 0b0001
        self.xrfdc.mts_dac_config.SysRef_Enable = 1
        self.xrfdc.mts_adc_config.SysRef_Enable = 1
        self.xrfdc.mts_dac_config.Target_Latency = -1
        self.xrfdc.mts_adc_config.Target_Latency = -1
        self.xrfdc.mts_dac()
        self.xrfdc.mts_adc()
        # Reset MTS ClockWizard MMCM - refer to PG065
        self.clocktreeMTS.MTSclkwiz.mmio.write_reg(CLOCKWIZARD_RESET_ADDRESS, CLOCKWIZARD_RESET_TOKEN)
        time.sleep(0.1)
        # Reset only user selected DAC tiles
        bitvector = self.ACTIVE_DAC_TILES
        for n in range(MAX_DAC_TILES):
            if (bitvector & 0x1):
                self.xrfdc.dac_tiles[n].Reset()
            bitvector = bitvector >> 1
        # Reset ADC FIFO of only user selected tiles - restarts MTS engine
        for toggleValue in range(0,1):
            bitvector = self.ACTIVE_ADC_TILES
            for n in range(MAX_ADC_TILES):
                if (bitvector & 0x1):
                    self.xrfdc.adc_tiles[n].SetupFIFOBoth(toggleValue)
                bitvector = bitvector >> 1"""
 
    def verify_clock_tree(self):
        """ Verify the PL and PL_SYSREF clocks are active by verifying an MMCM is in the LOCKED state"""
        Xstatus = self.clocktreeMTS.MTSclkwiz.read(CLOCKWIZARD_LOCK_ADDRESS) # reads the LOCK register
        # the ClockWizard AXILite registers are NOT fully mapped: refer to PG065
        if (Xstatus != 1):
            raise Exception("The MTS ClockTree has failed to LOCK. Please verify board clocking configuration")

    def trigger_dac(self):
        """ Internal loopback of DAC waveform to internal capture mirror"""        
        if self.stableFlag==0:
            return "Cannot trigger capture in dev version"
        self.trig_cap.off()
        self.dac_enable.off()
        self.dac_enable.on()
        #self.trig_cap.on() # actually triggers adc[A..C] to capture too
        #time.sleep(0.5)
        #self.trig_cap.off()
        return "ADCs disabled, trigger capture functions to endable DAC"

    def internal_capture(self, triplebuffer):
        """ Captures ADC samples from three channels and stores to internal memories """
        return "Internal capture not possible in stable or dev version"
        """if not np.issubdtype(triplebuffer.dtype, np.int16):
            raise Exception("buffer not defined or np.int16!")
        if not triplebuffer.shape[0] == 3:
            raise Exception("buffer must be of shape(3, N)!")
        self.trigger_capture()
        triplebuffer[0] = np.copy(self.adc_capture_chA[0:len(triplebuffer[0])])
        triplebuffer[1] = np.copy(self.adc_capture_chB[0:len(triplebuffer[1])])"""

    def dram_capture(self, buffer):
        """ Captures ADC samples to the PL-DRAM memory notebook provided buffer """
        
        return "DRAM capture is not possible in stable or dev version"
        """if type(buffer) != pynq.buffer.PynqBuffer:
            raise Exception("A PYNQ allocated buffer is required!")

        if not np.issubdtype(buffer.dtype, np.int16):
            raise Exception("buffer not defined or np.int16")
        
        self.dac_enable.on()
        self.adc_dma.register_map.S2MM_DMACR.Reset = 1
        self.adc_dma.recvchannel.stop()
        self.fifo_flush.off() # clear FIFO
        # because TLAST is not used, we must soft-reset the S2MM/recvchannel
        self.adc_dma.register_map.S2MM_DMACR.Reset = 0
        self.adc_dma.recvchannel.start()
        self.adc_dma.recvchannel.transfer(buffer)
        self.fifo_flush.on() # enable FIFO and samples will start flowing"""
    def frequency_round(self,freq,sampleRate,dataLength=(2/4)*1024**2): #default datalength is 2MB
        if self.stableFlag==1:
            roundedFrequency=(sampleRate/self.dac_player.shape[0])*round(freq/(sampleRate/self.dac_player.shape[0]))
        elif self.stableFlag==0:
           roundedFrequency=(sampleRate/dataLength)*round(freq/(sampleRate/dataLength)) 
        return roundedFrequency

def resolve_binary_path(bitfile_name):
    """ this helper function is necessary to locate the bit file during overlay loading"""
    if os.path.isfile(bitfile_name):
        return bitfile_name
    elif os.path.isfile(os.path.join(MODULE_PATH, bitfile_name)):
        return os.path.join(MODULE_PATH, bitfile_name)
    else:
        raise FileNotFoundError(f'Cannot find {bitfile_name}.')

# -------------------------------------------------------------------------------------------------

