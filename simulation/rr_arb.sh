verilator --binary -j 0 -Wall ../rtl/rr_arbiter.v ../tb/tb_rr_arbiter.v \
	--top tb_rr_arbiter --timing --CFLAGS "-std=c++20" \
	--trace

cd obj_dir || { echo "obj_dir not found"; exit 1; }
make -f Vtb_rr_arbiter.mk Vtb_rr_arbiter || { echo "Compilation failed"; exit 1; }
./Vtb_rr_arbiter || { echo "Simulation failed";  exit 1; }
