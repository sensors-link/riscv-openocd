OUTPUT_ARCH( "riscv" )

/* Entry Point */
ENTRY( entry )

/* System memory map */
MEMORY
{
	/* Application is stored in and executes from SRAM */
	RAM (RWX) : ORIGIN = 0x20000000, LENGTH = 4K
}

/* Section allocation in memory */
SECTIONS
{
	.text :
	{
		_text = .;
		*(.entry*)
		*(.text*)
		_etext = .;
	} > RAM

	.data :
	{	_data = .;
		PROVIDE( __global_pointer$ = . + 0x400 );
		*(.rodata*)
		*(.data*)
		_edata = .;
	}

	.bss :
	{
		__bss_start__ = .;
		_bss = .;
		*(.bss*)
		*(COMMON)
		_ebss = .;
		__bss_end__ = .;
	} > RAM

	 /* 将输入文件的comment段丢弃 */
	 /DISCARD/ : {*(.comment)} 
}
