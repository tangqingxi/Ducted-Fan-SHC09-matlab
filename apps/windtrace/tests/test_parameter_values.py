"""特殊数值和大数组必须保留实际参数，不能悄悄替换。"""
import json
import numpy as np
from core.exporter import parameter_snapshot


def test_inf_and_large_array_lossless():
    original=np.arange(240).reshape(80,3)
    snapshot,arrays=parameter_snapshot({'cfg':{'unbounded':float('inf'),'missing_value':float('nan'),'large':original}})
    json.dumps(snapshot,allow_nan=False)
    rows={r['path']:r for r in snapshot['entries']}
    assert rows['cfg.unbounded']['value']=={'special_float':'+Inf'}
    assert rows['cfg.missing_value']['value']=={'special_float':'NaN'}
    np.testing.assert_array_equal(arrays[rows['cfg.large']['value']['key']],original)
