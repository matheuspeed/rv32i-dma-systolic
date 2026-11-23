class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    soc_agent      agent;
    soc_ref_model  ref_model;
    soc_scoreboard scoreboard;
    soc_coverage   coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = soc_agent::type_id::create("agent", this);
        ref_model  = soc_ref_model::type_id::create("ref_model", this);
        scoreboard = soc_scoreboard::type_id::create("scoreboard", this);
        coverage   = soc_coverage::type_id::create("coverage", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.mon.ap.connect(scoreboard.obs_fifo.analysis_export);
        agent.mon.ap.connect(ref_model.analysis_export);
        agent.mon.ap.connect(coverage.analysis_export);
        ref_model.exp_ap.connect(scoreboard.exp_fifo.analysis_export);
    endfunction
endclass