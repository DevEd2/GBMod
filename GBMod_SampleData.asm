sample:	macro
	db	\1
	dw	\2,\3
	endm
	
GBM_SampleTable:
;	dw	Sample_Test1

;Sample_Test1:	sample	bank(testsample),testsample,testsample_end-testsample

section	"Sample data",romx
;testsample:	incbin	"lionwrath_kickbass.pcm"
;testsample_end
