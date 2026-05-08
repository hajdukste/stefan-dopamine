function events_aligned_table = myStruct2Mat(events_aligned)
    fields = fieldnames(events_aligned);
    values = cellfun(@(f) events_aligned.(f)(:), fields, 'UniformOutput', false);
    for i = 1:numel(values)
        if iscell(values{i}) && isrow(values{i})
            values{i} = values{i}(:);  % transpose cell row to column
        end
    end
    events_aligned_table = table(values{:}, 'VariableNames', fields');
end