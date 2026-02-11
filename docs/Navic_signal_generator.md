#Replicate the Pilot Signal of L1 band navic
- [Source](https://www.isro.gov.in/media_isro/pdf/SateliteNavigation/Draft_NavIC_SPS_ICD_L1_Oct_2022.pdf)
- [Source1](https://www.unoosa.org/documents/pdf/icg/2019/icg14/WGB/icg14_wgb_S5_3.pdf)
- [Source2](https://www.isro.gov.in/media_isro/pdf/SateliteNavigation/NavIC_SPS_ICD_L1_final.pdf)
The Pilot Signal has 2 codes 
1. Primary : 55 bit 2 reg and 5 bit reg
2. Secondary : 10 bit 2 reg 

The Module will be operate in 2 modes
1. Load - Initialize the block with the starting sequences from the input PRN ID
2. Generate - Give a the generated Code on a single pin

#Aim
To generate the pilot signal of Navic . Also measure the cross correlation with other signals .

#Test
- Power usage
- python clone
- auto and cross correlatiion
