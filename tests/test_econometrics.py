import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import numpy as np
import pandas as pd
from src.econometrics import absorb,fit_fe
from run_analysis import load_data

class EconometricsTests(unittest.TestCase):
 def test_absorption_matches_dummy_ols_on_unbalanced_panel(self):
  rng=np.random.default_rng(103); parish=np.repeat(np.arange(20),5); time=np.tile(np.arange(5),20)
  keep=rng.uniform(size=100)>.15; parish,time=parish[keep],time[keep]
  x=rng.normal(size=(len(parish),2)); y=x@np.array([.8,-.2])+parish*.1+time*.2+rng.normal(size=len(parish))
  f=fit_fe(y,x,[parish,time],parish,['a','b'])
  dummy=np.column_stack([np.ones(len(y)),pd.get_dummies(parish,drop_first=True),pd.get_dummies(time,drop_first=True)])
  direct=np.linalg.lstsq(np.column_stack([x,dummy]),y,rcond=None)[0][:2]
  np.testing.assert_allclose(f.beta,direct,atol=1e-9)
 def test_absorption_annihilates_group_means(self):
  x=np.arange(24,dtype=float).reshape(12,2); p=np.repeat([0,1,2],4); t=np.tile([0,1,2,3],3)
  z,_=absorb(x,[p,t]); self.assertLess(abs(z).max(),1e-10)
 def test_contrast_uses_covariance(self):
  from src.econometrics import Fit
  f=Fit(np.array([2.,1.]),np.array([[4.,1.],[1.,9.]]),['a','b'],100,20,2,2,1.)
  c=f.contrast({'a':1,'b':-1});self.assertAlmostEqual(c['estimate'],1);self.assertAlmostEqual(c['se'],np.sqrt(11))
 def test_real_panel_integrity(self):
  raw,d,_=load_data(); self.assertEqual(len(raw),26890);self.assertEqual(raw.parish_id.nunique(),5378)
  self.assertFalse(raw.duplicated(['parish_id','year']).any());self.assertEqual(int((d.min_distance_01<150).sum()),18185)
 def test_published_reconciliation(self):
  p=pd.read_csv(Path(__file__).resolve().parents[1]/'output/s16_reconciliation.csv')
  self.assertEqual(len(p),8)
  for col in ['coefficient_matches_rounding','n_matches','se_matches_rounding']: self.assertTrue(p[col].all(),col)
if __name__=='__main__': unittest.main()
