class soc_seq_item extends uvm_sequence_item;
    rand int unsigned M;
    rand int unsigned N;
    rand int unsigned K;
    rand bit          irq_en;
    rand logic [11:0] addr_a;
    rand logic [11:0] addr_b;
    rand logic [11:0] addr_c;

    rand byte signed  A[];
    rand byte signed  B[];

    // Campos de resposta / monitoramento
    int signed        C[];
    int unsigned      latency_cycles;
    int unsigned      array_size_cfg;

    constraint c_dims {
        M inside {2, 4, 8, 16};
        N inside {2, 4, 8, 16};
        K inside {[1:36]};
        (M * K) <= 1024;
        (K * N) <= 1024;
        (M * N) <= 256;
    }

    constraint c_addrs {
        addr_a == 12'h400;
        addr_b == 12'h800;
        addr_c == 12'hC00;
    }

    constraint c_sizes {
        A.size() == M * K;
        B.size() == K * N;
    }

    // Favorece fronteiras (-128, 0, 127) para COV-04
    constraint c_data_dist {
        foreach (A[i]) A[i] dist { -128 := 10, 0 := 10, 127 := 10, [-127:126] := 70 };
        foreach (B[i]) B[i] dist { -128 := 10, 0 := 10, 127 := 10, [-127:126] := 70 };
    }

    `uvm_object_utils_begin(soc_seq_item)
        `uvm_field_int(M, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(N, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(K, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(irq_en, UVM_ALL_ON)
        `uvm_field_int(addr_a, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(addr_b, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(addr_c, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(latency_cycles, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(array_size_cfg, UVM_ALL_ON | UVM_DEC)
        `uvm_field_array_int(A, UVM_ALL_ON)
        `uvm_field_array_int(B, UVM_ALL_ON)
        `uvm_field_array_int(C, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "soc_seq_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("MatMul(M=%0d, N=%0d, K=%0d, IRQ_EN=%0b, Cycles=%0d)",
                         M, N, K, irq_en, latency_cycles);
    endfunction
endclass