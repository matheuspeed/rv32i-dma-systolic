class soc_coverage extends uvm_subscriber #(soc_seq_item);
    `uvm_component_utils(soc_coverage)

    soc_seq_item tr;
    byte signed  sample_val;

    covergroup cg_soc;
        // COV-01: Configuração da malha
        cp_array_size: coverpoint tr.array_size_cfg {
            bins s2 = {2};
            bins s4 = {4};
            bins s8 = {8};
        }
        // COV-02: Blocos de K (BUF_DEPTH = 16)
        cp_k_blocks: coverpoint ((tr.K + 15) / 16) {
            bins one_blk  = {1};
            bins two_blks = {2};
            bins gt_two   = {[3:$]};
        }
        // COV-03: Dimensões M e N
        cp_dim_m: coverpoint tr.M {
            bins dim_2  = {2};
            bins dim_4  = {4};
            bins dim_8  = {8};
            bins dim_16 = {16};
        }
        cp_dim_n: coverpoint tr.N {
            bins dim_2  = {2};
            bins dim_4  = {4};
            bins dim_8  = {8};
            bins dim_16 = {16};
        }
        // COV-05: Modo de término
        cp_irq_mode: coverpoint tr.irq_en {
            bins polling = {1'b0};
            bins irq     = {1'b1};
        }
        // Cross obrigatório (Seção 7.2 do PDF)
        cx_dim_irq: cross cp_dim_m, cp_k_blocks, cp_irq_mode;
    endgroup

    // COV-04: Valores extremos
    covergroup cg_data;
        cp_val: coverpoint sample_val {
            bins min_neg = {-128};
            bins zero    = {0};
            bins max_pos = {127};
            bins others  = default;
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_soc  = new();
        cg_data = new();
    endfunction

    virtual function void write(soc_seq_item t);
        tr = t;
        cg_soc.sample();
        foreach (tr.A[i]) begin sample_val = tr.A[i]; cg_data.sample(); end
        foreach (tr.B[i]) begin sample_val = tr.B[i]; cg_data.sample(); end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV", $sformatf("Cobertura funcional: cg_soc=%.2f%% | cg_data=%.2f%%",
                                   cg_soc.get_coverage(), cg_data.get_coverage()), UVM_LOW)
    endfunction
endclass