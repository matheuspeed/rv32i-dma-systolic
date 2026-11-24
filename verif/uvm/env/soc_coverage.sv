class soc_coverage extends uvm_subscriber #(soc_seq_item);
    `uvm_component_utils(soc_coverage)

    soc_seq_item tr;
    byte signed  sample_val;

    covergroup cg_soc;
        option.per_instance = 1;

        // COV-01: Configuração da malha (cada execução cobre um bin; a regressão,
        // com ARRAY_SIZE = 2, 4 e 8, fecha os três na cobertura acumulada)
        cp_array_size: coverpoint tr.array_size_cfg {
            bins s2 = {2};
            bins s4 = {4};
            bins s8 = {8};
        }
        // COV-02: Blocos de K (BUF_DEPTH = 16): número de passagens por bloco de C
        cp_k_blocks: coverpoint ((tr.K + 15) / 16) {
            bins one_blk  = {1};
            bins two_blks = {2};
            bins gt_two   = {[3:$]};
        }
        // COV-02b: Fronteiras do tiling em K (plano de verificação, seção 6.2):
        // pedaço mínimo, buffer exatamente cheio e um elemento além do buffer,
        // onde o último pedaço tem klen = 1.
        cp_k_boundary: coverpoint tr.K {
            bins k1  = {1};    // menor pedaço possível
            bins k16 = {16};   // um pedaço com o buffer exatamente cheio
            bins k17 = {17};   // segundo pedaço com klen = 1
            bins k32 = {32};   // dois pedaços cheios
            bins k33 = {33};   // terceiro pedaço com klen = 1
        }
        // COV-03: Dimensões M e N medidas em blocos de ARRAY_SIZE (laços ti e tj do DMA).
        // Em blocos, todos os bins são alcançáveis em qualquer configuração; em valores
        // absolutos, M = 2 ou 4 seriam impossíveis com ARRAY_SIZE = 8.
        cp_m_blocks: coverpoint (tr.M / tr.array_size_cfg) iff (tr.array_size_cfg != 0) {
            bins one   = {1};
            bins multi = {[2:$]};
        }
        cp_n_blocks: coverpoint (tr.N / tr.array_size_cfg) iff (tr.array_size_cfg != 0) {
            bins one   = {1};
            bins multi = {[2:$]};
        }
        // COV-05: Modo de término
        cp_irq_mode: coverpoint tr.irq_en {
            bins polling = {1'b0};
            bins irq     = {1'b1};
        }
        // Cross obrigatório (Seção 7.2 do PDF): blocos de C em M x passagens em K x término
        cx_blocks_k_irq: cross cp_m_blocks, cp_k_blocks, cp_irq_mode;
    endgroup

    // COV-04: Valores extremos
    covergroup cg_data;
        option.per_instance = 1;
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
        cg_soc.set_inst_name("cg_soc");
        cg_data.set_inst_name("cg_data");
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
                                   cg_soc.get_inst_coverage(), cg_data.get_inst_coverage()), UVM_NONE)
        `uvm_info("COV", $sformatf("  cg_soc: array_size=%.2f%% k_blocks=%.2f%% k_boundary=%.2f%% m_blocks=%.2f%% n_blocks=%.2f%% irq_mode=%.2f%% cross=%.2f%%",
                                   cg_soc.cp_array_size.get_inst_coverage(),
                                   cg_soc.cp_k_blocks.get_inst_coverage(),
                                   cg_soc.cp_k_boundary.get_inst_coverage(),
                                   cg_soc.cp_m_blocks.get_inst_coverage(),
                                   cg_soc.cp_n_blocks.get_inst_coverage(),
                                   cg_soc.cp_irq_mode.get_inst_coverage(),
                                   cg_soc.cx_blocks_k_irq.get_inst_coverage()), UVM_NONE)
    endfunction
endclass