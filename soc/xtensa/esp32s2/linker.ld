/*
 * Copyright (c) 2021 Espressif Systems (Shanghai) Co., Ltd.
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * @file
 * @brief Linker command/script file
 *
 * Linker script for the esp32s2 platform.
 */

#include <devicetree.h>
#include <autoconf.h>
#include <linker/sections.h>
#include <linker/linker-defs.h>
#include <linker/linker-tool.h>

#define RAM_IRAM_START    0x40020000
#define RAM_DRAM_START    0x3ffb0000

#define DATA_RAM_END      0x3ffe0000  /* 2nd stage bootloader iram_loader_seg
                                       * starts at SRAM block 14 (reclaimed after
                                       * app boots)
                                       */

#define IRAM_ORG    (RAM_IRAM_START + CONFIG_ESP32S2_INSTRUCTION_CACHE_SIZE \
                                    + CONFIG_ESP32S2_DATA_CACHE_SIZE)

#define DRAM_ORG    (RAM_DRAM_START + CONFIG_ESP32S2_INSTRUCTION_CACHE_SIZE \
                                    + CONFIG_ESP32S2_DATA_CACHE_SIZE)

#define I_D_RAM_SIZE   DATA_RAM_END - DRAM_ORG

#define RAMABLE_REGION dram0_0_seg
#define RODATA_REGION drom0_0_seg
#define IRAM_REGION iram0_0_seg
#define FLASH_CODE_REGION irom0_0_seg

#define ROMABLE_REGION ROM

#ifdef CONFIG_FLASH_SIZE
#define FLASH_SIZE CONFIG_FLASH_SIZE
#else
#define FLASH_SIZE 0x400000
#endif

#ifdef CONFIG_BOOTLOADER_ESP_IDF
#define IROM_SEG_ORG 0x40080020
#define IROM_SEG_LEN (FLASH_SIZE-0x20)
#define IROM_SEG_ALIGN 0x4
#else
#define IROM_SEG_ORG 0x40080000
#define IROM_SEG_LEN FLASH_SIZE
#define IROM_SEG_ALIGN 0x10000
#endif

MEMORY
{
  mcuboot_hdr (RX): org = 0x0, len = 0x20
  metadata (RX): org = 0x20, len = 0x20
  ROM (RX): org = 0x40, len = FLASH_SIZE - 0x40
  iram0_0_seg(RX): org = IRAM_ORG, len = I_D_RAM_SIZE
  irom0_0_seg(RX): org = IROM_SEG_ORG, len = IROM_SEG_LEN
  dram0_0_seg(RW): org = DRAM_ORG, len = I_D_RAM_SIZE
  drom0_0_seg(R): org = 0x3f000040, len = FLASH_SIZE - 0x40

  rtc_iram_seg(RWX): org = 0x40070000, len = 0x2000
  rtc_slow_seg(RW): org = 0x50000000, len = 0x2000
#if defined(CONFIG_ESP_SPIRAM)
  ext_ram_seg(RW): org = 0x3f500000, len = CONFIG_ESP_SPIRAM_SIZE
#endif
#ifdef CONFIG_GEN_ISR_TABLES
  IDT_LIST(RW): org = 0x3ebfe010, len = 0x2000
#endif
}

/*  Default entry point:  */
ENTRY(CONFIG_KERNEL_ENTRY)

_rom_store_table = 0;

SECTIONS
{
  /* Reserve space for MCUboot header in the binary */
  .mcuboot_header :
  {
    QUAD(0x0)
    QUAD(0x0)
    QUAD(0x0)
    QUAD(0x0)
  } > mcuboot_hdr
  .metadata :
  {
    /* Magic byte for load header */
    LONG(0xace637d3)

    /* Application entry point address */
    KEEP(*(.entry_addr))

    /* IRAM metadata:
     * - Destination address (VMA) for IRAM region
     * - Flash offset (LMA) for start of IRAM region
     * - Size of IRAM region
     */
    LONG(ADDR(.iram0.vectors))
    LONG(LOADADDR(.iram0.vectors))
    LONG(LOADADDR(.iram0.text) + SIZEOF(.iram0.text) - LOADADDR(.iram0.vectors))

    /* DRAM metadata:
     * - Destination address (VMA) for DRAM region
     * - Flash offset (LMA) for start of DRAM region
     * - Size of DRAM region
     */
    LONG(ADDR(.dram0.data))
    LONG(LOADADDR(.dram0.data))
    LONG(LOADADDR(.dummy.dram.data) + SIZEOF(.dummy.dram.data) - LOADADDR(.dram0.data))
  } > metadata

#include <linker/rel-sections.ld>
  _image_drom_start = LOADADDR(_RODATA_SECTION_NAME);
  _image_drom_size = LOADADDR(_RODATA_SECTION_NAME) + SIZEOF(_RODATA_SECTION_NAME) - _image_drom_start;
  _image_drom_vaddr = ADDR(_RODATA_SECTION_NAME);

  /* NOTE: .rodata section should be the first section in the linker script and no
   * other section should appear before .rodata section. This is the requirement
   * to align ROM section to 64K page offset.
   * Adding .rodata as first section helps to reduce size of generated binary by
   * few kBs.
   */
  SECTION_PROLOGUE(_RODATA_SECTION_NAME,,)
  {
    _rodata_start = ABSOLUTE(.);

    *(.rodata_desc .rodata_desc.*)
    *(.rodata_custom_desc .rodata_custom_desc.*)

#ifdef CONFIG_USERSPACE
    Z_LINK_ITERABLE_ALIGNED(z_object_assignment, 4);
#endif

#if defined(CONFIG_NET_SOCKETS)
    Z_LINK_ITERABLE_ALIGNED(net_socket_register, 4);
#endif

#if defined(CONFIG_NET_L2_PPP)
    Z_LINK_ITERABLE_ALIGNED(ppp_protocol_handler, 4);
#endif

    Z_LINK_ITERABLE_ALIGNED(bt_l2cap_fixed_chan, 4);

#if defined(CONFIG_BT_BREDR)
    Z_LINK_ITERABLE_ALIGNED(bt_l2cap_br_fixed_chan, 4);
#endif

#if defined(CONFIG_BT_CONN)
    Z_LINK_ITERABLE_ALIGNED(bt_conn_cb, 4)
#endif

    Z_LINK_ITERABLE_ALIGNED(bt_gatt_service_static, 4);

#if defined(CONFIG_BT_MESH)
    Z_LINK_ITERABLE_ALIGNED(bt_mesh_subnet_cb, 4);
    Z_LINK_ITERABLE_ALIGNED(bt_mesh_app_key_cb, 4);
    Z_LINK_ITERABLE_ALIGNED(bt_mesh_hb_cb, 4);
#endif

#if defined(CONFIG_BT_MESH_FRIEND)
    Z_LINK_ITERABLE_ALIGNED(bt_mesh_friend_cb, 4);
#endif

#if defined(CONFIG_BT_MESH_LOW_POWER)
    Z_LINK_ITERABLE_ALIGNED(bt_mesh_lpn_cb, 4);
#endif

#if defined(CONFIG_BT_MESH_PROXY)
    Z_LINK_ITERABLE_ALIGNED(bt_mesh_proxy_cb, 4);
#endif

#if defined(CONFIG_EC_HOST_CMD)
    Z_LINK_ITERABLE_ALIGNED(ec_host_cmd_handler, 4);
#endif

#if defined(CONFIG_SETTINGS)
    Z_LINK_ITERABLE_ALIGNED(settings_handler_static, 4);
#endif

    Z_LINK_ITERABLE_ALIGNED(k_p4wq_initparam, 4);

    Z_LINK_ITERABLE_ALIGNED(shell, 4);

    Z_LINK_ITERABLE_ALIGNED(tracing_backend, 4)

    __esp_shell_root_cmds_start = .;
    KEEP(*(SORT(.shell_root_cmd_*)));
    __esp_shell_root_cmds_end = .;

    . = ALIGN(4);
    #include <snippets-rodata.ld>

    . = ALIGN(4);
    *(EXCLUDE_FILE (*libarch__xtensa__core.a:* *libkernel.a:fatal.* *libkernel.a:init.* *libzephyr.a:cbprintf_complete* *libzephyr.a:log_core.* *libzephyr.a:log_backend_uart.* *libzephyr.a:log_output.* *libzephyr.a:loader.* *libdrivers__flash.a:flash_esp32.* *libdrivers__serial.a:uart_esp32.*) .rodata)
    *(EXCLUDE_FILE (*libarch__xtensa__core.a:* *libkernel.a:fatal.* *libkernel.a:init.* *libzephyr.a:cbprintf_complete* *libzephyr.a:log_core.* *libzephyr.a:log_backend_uart.* *libzephyr.a:log_output.* *libzephyr.a:loader.* *libdrivers__flash.a:flash_esp32.* *libdrivers__serial.a:uart_esp32.*) .rodata.*)

    . = ALIGN(4);
    *(.irom1.text) /* catch stray ICACHE_RODATA_ATTR */
    *(.gnu.linkonce.r.*)
    *(.rodata1)
    __XT_EXCEPTION_TABLE_ = ABSOLUTE(.);
    *(.xt_except_table)
    *(.gcc_except_table .gcc_except_table.*)
    *(.gnu.linkonce.e.*)
    *(.gnu.version_r)
    . = (. + 3) & ~ 3;
    __eh_frame = ABSOLUTE(.);
    KEEP(*(.eh_frame))
    . = (. + 7) & ~ 3;
    /* C++ constructor and destructor tables */
    __init_array_start = ABSOLUTE(.);
    KEEP (*(EXCLUDE_FILE (*crtend.* *crtbegin.*) .ctors SORT(.ctors.*)))
    __init_array_end = ABSOLUTE(.);
    KEEP (*crtbegin.*(.dtors))
    KEEP (*(EXCLUDE_FILE (*crtend.*) .dtors))
    KEEP (*(SORT(.dtors.*)))
    KEEP (*(.dtors))
    /*  C++ exception handlers table:  */
    __XT_EXCEPTION_DESCS_ = ABSOLUTE(.);
    *(.xt_except_desc)
    *(.gnu.linkonce.h.*)
    __XT_EXCEPTION_DESCS_END__ = ABSOLUTE(.);
    *(.xt_except_desc_end)
    *(.dynamic)
    *(.gnu.version_d)
    _rodata_end = ABSOLUTE(.);
    /* Literals are also RO data. */
    _lit4_start = ABSOLUTE(.);
    *(*.lit4)
    *(.lit4.*)
    *(.gnu.linkonce.lit4.*)
    _lit4_end = ABSOLUTE(.);
    . = ALIGN(4);
    _thread_local_start = ABSOLUTE(.);
    *(.tdata)
    *(.tdata.*)
    *(.tbss)
    *(.tbss.*)
    _thread_local_end = ABSOLUTE(.);
    _rodata_reserved_end = ABSOLUTE(.);
    . = ALIGN(4);
  } GROUP_DATA_LINK_IN(RODATA_REGION, ROMABLE_REGION)

  /* Send .iram0 code to iram */
  .iram0.vectors : ALIGN(4)
  {
    _iram_start = ABSOLUTE(.);
    /* Vectors go to IRAM */
    _init_start = ABSOLUTE(.);
    /* Vectors according to builds/RF-2015.2-win32/esp108_v1_2_s5_512int_2/config.html */
    . = 0x0;
    KEEP(*(.WindowVectors.text));
    . = 0x180;
    KEEP(*(.Level2InterruptVector.text));
    . = 0x1c0;
    KEEP(*(.Level3InterruptVector.text));
    . = 0x200;
    KEEP(*(.Level4InterruptVector.text));
    . = 0x240;
    KEEP(*(.Level5InterruptVector.text));
    . = 0x280;
    KEEP(*(.DebugExceptionVector.text));
    . = 0x2c0;
    KEEP(*(.NMIExceptionVector.text));
    . = 0x300;
    KEEP(*(.KernelExceptionVector.text));
    . = 0x340;
    KEEP(*(.UserExceptionVector.text));
    . = 0x3C0;
    KEEP(*(.DoubleExceptionVector.text));
    . = 0x400;
    *(.*Vector.literal)

    *(.UserEnter.literal);
    *(.UserEnter.text);
    . = ALIGN (16);
    *(.entry.text)
    *(.init.literal)
    *(.init)
    _init_end = ABSOLUTE(.);

    /* This goes here, not at top of linker script, so addr2line finds it last,
       and uses it in preference to the first symbol in IRAM */
  } GROUP_DATA_LINK_IN(IRAM_REGION, ROMABLE_REGION)

  .iram0.text : ALIGN(4)
  {
    /* Code marked as running out of IRAM */
    *(.iram1 .iram1.*)
    *(.iram0.literal .iram.literal .iram.text.literal .iram0.text .iram.text)
    *libesp32.a:panic.*(.literal .text .literal.* .text.*)
    *librtc.a:(.literal .text .literal.* .text.*)
    *libsubsys__net__l2__ethernet.a:(.literal .text .literal.* .text.*)
    *libsubsys__net__lib__config.a:(.literal .text .literal.* .text.*)
    *libsubsys__net__ip.a:(.literal .text .literal.* .text.*)
    *libsubsys__net.a:(.literal .text .literal.* .text.*)
    *libarch__xtensa__core.a:(.literal .text .literal.* .text.*)
    *libkernel.a:(.literal .text .literal.* .text.*)
    *libsoc.a:rtc_*.*(.literal .text .literal.* .text.*)
    *libsoc.a:cpu_util.*(.literal .text .literal.* .text.*)
    *libgcc.a:lib2funcs.*(.literal .text .literal.* .text.*)
    *libdrivers__flash.a:flash_esp32.*(.literal .text .literal.* .text.*)
    *libzephyr.a:windowspill_asm.*(.literal .text .literal.* .text.*)
    *libzephyr.a:log_noos.*(.literal .text .literal.* .text.*)
    *libdrivers__timer.a:xtensa_sys_timer.*(.literal .text .literal.* .text.*)
    *libzephyr.a:log_core.*(.literal .text .literal.* .text.*)
    *libzephyr.a:cbprintf_complete.*(.literal .text .literal.* .text.*)
    *libzephyr.a:printk.*(.literal.printk .literal.vprintk .literal.char_out .text.printk .text.vprintk .text.char_out)
    *libzephyr.a:log_msg.*(.literal .text .literal.* .text.*)
    *libzephyr.a:log_list.*(.literal .text .literal.* .text.*)
    *libdrivers__console.a:uart_console.*(.literal.console_out .text.console_out)
    *libzephyr.a:log_output.*(.literal .text .literal.* .text.*)
    *libzephyr.a:log_backend_uart.*(.literal .text .literal.* .text.*)
    *libzephyr.a:loader.*(.literal .text .literal.* .text.*)
    *liblib__libc__minimal.a:string.*(.literal .text .literal.* .text.*)
    *libphy.a:( .phyiram .phyiram.*)
    *libgcov.a:(.literal .text .literal.* .text.*)

#if defined(CONFIG_ESP32_WIFI_IRAM_OPT)
    *libnet80211.a:( .wifi0iram  .wifi0iram.* .wifislpiram .wifislpiram.*)
    *libpp.a:( .wifi0iram  .wifi0iram.* .wifislpiram .wifislpiram.*)
#endif

#if defined(CONFIG_ESP32_WIFI_RX_IRAM_OPT)
    *libnet80211.a:( .wifirxiram  .wifirxiram.* .wifislprxiram .wifislprxiram.*)
    *libpp.a:( .wifirxiram  .wifirxiram.* .wifislprxiram .wifislprxiram.*)
#endif

    /* align + add 16B for CPU dummy speculative instr. fetch */
    . = ALIGN(4) + 16;
    _iram_text = ABSOLUTE(.);
  } GROUP_DATA_LINK_IN(IRAM_REGION, ROMABLE_REGION)

  .dram0.dummy (NOLOAD):
  {
    /**
    * This section is required to skip .iram0.text area because iram0_0_seg and
    * dram0_0_seg reflect the same address space on different buses.
    */
    . = ORIGIN(dram0_0_seg) + _iram_end - _iram_start;
  } GROUP_LINK_IN(RAMABLE_REGION)

  /* Shared RAM */
  SECTION_DATA_PROLOGUE(_BSS_SECTION_NAME,(NOLOAD),)
  {
    . = ALIGN (8);
    __bss_start = ABSOLUTE(.);
    *(.dynsbss)
    *(.sbss)
    *(.sbss.*)
    *(.gnu.linkonce.sb.*)
    *(.scommon)
    *(.sbss2)
    *(.sbss2.*)
    *(.gnu.linkonce.sb2.*)
    *(.dynbss)
    *(.bss)
    *(.bss.*)
    *(.share.mem)
    *(.gnu.linkonce.b.*)
    *(COMMON)
    . = ALIGN (8);
    __bss_end = ABSOLUTE(.);
  } GROUP_LINK_IN(RAMABLE_REGION)

  SECTION_DATA_PROLOGUE(_NOINIT_SECTION_NAME, (NOLOAD),)
  {
    . = ALIGN(8);
    *(.noinit)
    *(.noinit.*)
    . = ALIGN(8);
  } GROUP_LINK_IN(RAMABLE_REGION)

#include <snippets-sections.ld>

  .dram0.data :
  {
    _data_start = ABSOLUTE(.);
    *(.data)
    *(.data.*)
    *(.gnu.linkonce.d.*)
    *(.data1)
    *(.sdata)
    *(.sdata.*)
    *(.gnu.linkonce.s.*)
    *(.sdata2)
    *(.sdata2.*)
    *(.gnu.linkonce.s2.*)
    /* rodata for panic handler(libarch__xtensa__core.a) and all
     * dependent functions should be placed in DRAM to avoid issue
     * when flash cache is disabled */
    *libarch__xtensa__core.a:(.rodata .rodata.*)
    *libkernel.a:fatal.*(.rodata .rodata.*)
    *libkernel.a:init.*(.rodata .rodata.*)
    *libzephyr.a:cbprintf_complete*(.rodata .rodata.*)
    *libzephyr.a:log_core.*(.rodata .rodata.*)
    *libzephyr.a:log_backend_uart.*(.rodata .rodata.*)
    *libzephyr.a:log_output.*(.rodata .rodata.*)
    *libzephyr.a:loader.*(.rodata .rodata.*)
    *libdrivers__flash.a:flash_esp32.*(.rodata  .rodata.*)
    *libdrivers__serial.a:uart_esp32.*(.rodata .rodata.*)

    KEEP(*(.jcr))
    *(.dram1 .dram1.*)
    . = ALIGN(4);
  } GROUP_DATA_LINK_IN(RAMABLE_REGION, ROMABLE_REGION)

  #pragma push_macro("GROUP_ROM_LINK_IN")
  #pragma push_macro("ITERABLE_SECTION_ROM")
  #undef GROUP_ROM_LINK_IN
  #undef ITERABLE_SECTION_ROM
  #define GROUP_ROM_LINK_IN GROUP_DATA_LINK_IN
  #define ITERABLE_SECTION_ROM(x,y)
  #include <linker/common-rom.ld>
  #pragma pop_macro("GROUP_ROM_LINK_IN")
  #pragma pop_macro("ITERABLE_SECTION_ROM")

  #include <snippets-data-sections.ld>
  #include <linker/common-ram.ld>
  #include <snippets-ram-sections.ld>

  __shell_root_cmds_start = __esp_shell_root_cmds_start;
  __shell_root_cmds_end = __esp_shell_root_cmds_end;

  .dummy.dram.data :
  {
    . = ALIGN(4);
    #include <snippets-rwdata.ld>
    . = ALIGN(4);
    _data_end = ABSOLUTE(.);
  } GROUP_DATA_LINK_IN(RAMABLE_REGION, ROMABLE_REGION)

  .iram0.text_end (NOLOAD) :
  {
    . = ALIGN(4);
    _iram_end = ABSOLUTE(.);
  } GROUP_LINK_IN(IRAM_REGION)

  _image_irom_start = LOADADDR(.flash.text);
  _image_irom_size = LOADADDR(.flash.text) + SIZEOF(.flash.text) - _image_irom_start;
  _image_irom_vaddr = ADDR(.flash.text);

  .flash_text_dummy (NOLOAD): ALIGN(IROM_SEG_ALIGN)
  {
    . = SIZEOF(_RODATA_SECTION_NAME);
  } GROUP_LINK_IN(FLASH_CODE_REGION)

  .flash.text : ALIGN(IROM_SEG_ALIGN)
  {
    _stext = .;
    _text_start = ABSOLUTE(.);

#if !defined(CONFIG_ESP32_WIFI_IRAM_OPT)
    *libnet80211.a:( .wifi0iram  .wifi0iram.* .wifislpiram .wifislpiram.*)
    *libpp.a:( .wifi0iram  .wifi0iram.* .wifislpiram .wifislpiram.*)
#endif

#if !defined(CONFIG_ESP32_WIFI_RX_IRAM_OPT)
    *libnet80211.a:( .wifirxiram  .wifirxiram.* .wifislprxiram .wifislprxiram.*)
    *libpp.a:( .wifirxiram  .wifirxiram.* .wifislprxiram .wifislprxiram.*)
#endif

    *(.literal .text .literal.* .text.*)
    _text_end = ABSOLUTE(.);
    _etext = .;

    /* Similar to _iram_start, this symbol goes here so it is
       resolved by addr2line in preference to the first symbol in
       the flash.text segment.
    */
    _flash_cache_start = ABSOLUTE(0);
  } GROUP_DATA_LINK_IN(FLASH_CODE_REGION, ROMABLE_REGION)

  /* RTC fast memory holds RTC wake stub code,
     including from any source file named rtc_wake_stub*.c
  */
  .rtc.text :
  {
    . = ALIGN(4);
    *(.rtc.literal .rtc.text)
    *rtc_wake_stub*.o(.literal .text .literal.* .text.*)
  } GROUP_DATA_LINK_IN(rtc_iram_seg, ROMABLE_REGION)

  /* RTC slow memory holds RTC wake stub
     data/rodata, including from any source file
     named rtc_wake_stub*.c
  */
  .rtc.data :
  {
    _rtc_data_start = ABSOLUTE(.);
    *(.rtc.data)
    *(.rtc.rodata)
    *rtc_wake_stub*.o(.data .rodata .data.* .rodata.* .bss .bss.*)
    _rtc_data_end = ABSOLUTE(.);
  } GROUP_DATA_LINK_IN(rtc_slow_seg, ROMABLE_REGION)

  /* RTC bss, from any source file named rtc_wake_stub*.c */
  .rtc.bss (NOLOAD) :
  {
    _rtc_bss_start = ABSOLUTE(.);
    *rtc_wake_stub*.o(.bss .bss.*)
    *rtc_wake_stub*.o(COMMON)
    _rtc_bss_end = ABSOLUTE(.);
  } GROUP_LINK_IN(rtc_slow_seg)

#if defined(CONFIG_ESP_SPIRAM)
  .ext_ram.bss (NOLOAD):
  {
    _ext_ram_bss_start = ABSOLUTE(.);
    *(.ext_ram.bss*)
    . = ALIGN(4);
    _ext_ram_bss_end = ABSOLUTE(.) + CONFIG_ESP_SPIRAM_SIZE;
  } > ext_ram_seg
#endif

#ifdef CONFIG_GEN_ISR_TABLES
#include <linker/intlist.ld>
#endif

#include <linker/debug-sections.ld>

  SECTION_PROLOGUE(.xtensa.info, 0,)
  {
    *(.xtensa.info)
  }
}

ASSERT(((__bss_end - ORIGIN(dram0_0_seg)) <= LENGTH(dram0_0_seg)),
          "DRAM0 segment data does not fit.")

ASSERT(((_iram_end - ORIGIN(iram0_0_seg)) <= LENGTH(iram0_0_seg)),
          "IRAM0 segment data does not fit.")
