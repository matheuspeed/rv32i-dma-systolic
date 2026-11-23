class soc_directed_test extends soc_base_test;
    `uvm_component_utils(soc_directed_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_directed_seq seq;
        phase.raise_objection(this);

        seq = soc_directed_seq::type_id::create("seq");
        seq.array_size = cfg.array_size;
        seq.start(env.agent.sqr);

        phase.drop_objection(this);
    endtask
endclass