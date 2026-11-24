# Combina a cobertura das execucoes da regressao e imprime o resumo
# Uso (de dentro de sim/): imc -exec merge_cov.tcl
merge cov_work/scope/*_seed* -out cov_work/scope/merged -overwrite -initial_model union_all
load -run cov_work/scope/merged
report -summary -metrics covergroup
exit
