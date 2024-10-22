# UIcalculator

To use this function, first
- Run `do https://github.com/pithymaxim/UIcalculator/raw/refs/heads/main/calculator_github.do` in Stata

The full Stata script example below makes an example dataset with five hypothetical claimants, runs the github code to define the function, and then calculates monetary eligiblity for the 5 claimants. The list command at the bottom shows that the predictions have now been added.

```
clear
input int id str2 state int year byte hqe byte hqe2 float bpe float aww byte construction byte hours byte lackwork byte quit
1 "CA" 2023 1 0 45000 865.38  0 40 0 0
2 "NY" 2022 1 1 52000 1000.00 0 35 1 0
3 "TX" 2022 0 0 38000 730.77  1 45 0 1
4 "FL" 2022 0 1 62000 1192.31 0 38 1 0
5 "WA" 2003 1 0 41000 788.46  1 42 0 0
end

do https://github.com/pithymaxim/UIcalculator/raw/refs/heads/main/calculator_github.do

CALCULATOR_MONETARY, hqe(hqe) bpe(bpe) state(state) year(year) hqe2(hqe2) aww(aww) construction(construction) hours(hours) lackwork(lackwork)  quit(quit) deflated(1)

list id state year Predict_wba-Predict_eligibility_all
```
