verilator --binary -j 0 -Wall ../rtl/sync_fifo.v ../tb/tb_sync_fifo.v \
	--top tb_sync_fifo --timing --CFLAGS "-std=c++20" \
	--trace

cd obj_dir || { echo "obj_dir not found"; exit 1; }
make -f Vtb_sync_fifo.mk Vtb_sync_fifo || { echo "Compilation failed"; exit 1; }
./Vtb_sync_fifo || { echo "Simulation failed";  exit 1; }
