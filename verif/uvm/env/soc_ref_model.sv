class soc_ref_model extends uvm_subscriber #(soc_seq_item);
    `uvm_component_utils(soc_ref_model)

    uvm_analysis_port #(soc_seq_item) exp_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        exp_ap = new("exp_ap", this);
    endfunction

    virtual function void write(soc_seq_item t);
        soc_seq_item exp;
        int signed acc;

        exp = soc_seq_item::type_id::create("exp");
        exp.copy(t);
        exp.C = new[t.M * t.N];

        for (int unsigned i = 0; i < t.M; i++) begin
            for (int unsigned j = 0; j < t.N; j++) begin
                acc = 0;
                for (int unsigned k = 0; k < t.K; k++) begin
                    acc += int'(t.A[i * t.K + k]) * int'(t.B[k * t.N + j]);
                end
                exp.C[i * t.N + j] = acc;
            end
        end

        exp_ap.write(exp);
    endfunction
endclass