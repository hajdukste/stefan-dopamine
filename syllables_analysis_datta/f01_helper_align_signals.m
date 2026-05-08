function aligned = f01_helper_align_signals(d, events, config)
% Extract aligned traces from .d table around event times
%
% d       - table with time, zsc_exp, speed, etc.
% events  - struct with .time_idx (indices into d)
% config  - struct with .t_before, .t_after, .trace_types

    t_before = config.t_before;
    t_after = config.t_after;
    trace_types = config.trace_types;
    n_events = length(events.time_idx);
    rows_to_drop = [];

    for i_trace = 1:length(trace_types)
        trace_name = trace_types{i_trace};
        traces = cell(n_events, 1);

        for i_event = 1:n_events
            idx = events.time_idx(i_event);
            win = (idx - t_before):(idx + t_after);
            if any(win < 1) || any(win > height(d))
                rows_to_drop(end+1) = i_event;
                continue;
            end
            traces{i_event} = d.(trace_name)(win);
        end

        events.(trace_name) = traces;
    end

    rows_to_drop = unique(rows_to_drop);
    if ~isempty(rows_to_drop)
        field_names = fieldnames(events);
        for i = 1:length(field_names)
            events.(field_names{i})(rows_to_drop) = [];
        end
    end

    aligned = events;
end
