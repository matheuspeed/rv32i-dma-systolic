class soc_random_test extends soc_base_test;
    `uvm_component_utils(soc_random_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_random_seq seq;
        int unsigned   ntxns = 15;

        phase.raise_objection(this);
        void'($value$plusargs("NTXNS=%d", ntxns));

        seq = soc_random_seq::type_id::create("seq");
        seq.array_size = cfg.array_size;
        seq.num_txns   = ntxns;
        seq.start(env.agent.sqr);

        phase.drop_objection(this);
    endtask
endclass