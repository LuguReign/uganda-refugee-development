#!/usr/bin/env python3
"""Replicate selected published public-goods models and run one exploratory extension."""
from pathlib import Path
import hashlib,json,platform,sys
import numpy as np
import pandas as pd
from src.econometrics import fit_fe
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'output'; OUT.mkdir(exist_ok=True)
CONTROLS=['population_census2002','average_age_census2002','proportion_male_census2002','literacy_rate_census2002','unemployment_rate_census2002','agriculture_share_census2002','coethnic_share_census2002','wealth_index_census2002','any_violent_event_census2002','distance_to_nearest_oil_well_in_km','borderdist','roaddist','capitoldist']
OUTCOMES={
'Public primary schools':'public_primary_schools_per_thousand_kids_parish_level_standardized',
'Public secondary schools':'public_per_thousand_kid_standardized',
'Road density':'road_density_standardized',
'HC2 clinics':'minmax_count_pop_hcii_standardized',
'HC3 centers':'multiply4_minmax_hciii_standardized',
'HC4 centers':'multiply4_minmax_hciv_standardized',
'HC5 hospitals':'multiply4_minmax_hcv_standardized',
'Public goods index':'PGindex_mean'}
EXPECTED=[(.058,.025,18178),(-.012,.029,18178),(.179,.032,10904),(-.160,.034,14548),(.110,.027,14548),(-.061,.025,14548),(.068,.028,14548),(.031,.005,18178)]

def load_data():
    source=ROOT/'data/raw/political_data_merged_Dev_Econ_Paper.csv'
    if not source.exists(): source=source.with_suffix('.csv.gz')
    raw=pd.read_csv(source,low_memory=False)
    if raw.duplicated(['parish_id','year']).any(): raise ValueError('Duplicate parish-year key')
    if set(raw.year)!={2001,2006,2011,2016,2020}: raise ValueError('Unexpected wave')
    # Authors standardize transformed presence BEFORE dropping controls/radius.
    nearest=np.arcsinh(raw.nearest_exposure)
    combined=np.arcsinh(np.where(raw.min_distance<20,raw.sum_exposure_20km_rad,raw.nearest_exposure))
    raw['presence']=(combined-np.nanmean(combined))/np.nanstd(combined,ddof=1)
    raw['nearest_z']=(nearest-np.nanmean(nearest))/np.nanstd(nearest,ddof=1)
    complete=raw.dropna(subset=['min_distance']+CONTROLS).copy()
    # Faithful replication: the SI uses quantiles of NEAREST for Nearest+20 bins.
    breaks=complete.nearest_z.quantile([0,.5,1]).to_numpy()
    complete['binary_presence']=pd.cut(complete.presence,breaks,labels=[0,1],include_lowest=True).astype(float)
    complete['s16_treatment']=np.where(complete.year>=2016,complete.binary_presence,0)
    complete['region_year']=complete.region.astype(str)+':'+complete.year.astype(str)
    return raw,complete,breaks

def design(data,years,extension=False,binary=False):
    names=['treatment'] if binary else ['presence']+[f'presence_{y}' for y in years]
    columns=[data.s16_treatment.to_numpy()] if binary else [data.presence.to_numpy()]+[(data.presence*(data.year==y)).to_numpy() for y in years]
    for year in years:
        for control in CONTROLS:
            names.append(f'{control}_{year}'); columns.append((data[control]*(data.year==year)).to_numpy())
    if extension:
        names+=['presence_low']+[f'presence_low_{y}' for y in years]+[f'low_{y}' for y in years]
        columns += [(data.presence*data.low_access).to_numpy()]+[(data.presence*data.low_access*(data.year==y)).to_numpy() for y in years]+[(data.low_access*(data.year==y)).to_numpy() for y in years]
    return np.column_stack(columns),names

def estimate(data,outcome,radius=150,binary=False,extension=False):
    health='minmax' in outcome; road='road_density' in outcome
    years=[2016,2020] if road else [2006,2011,2016] if health else [2006,2011,2016,2020]
    d=data[data.min_distance_01<radius].copy().dropna(subset=[outcome,'s16_treatment' if binary else 'presence'])
    if extension: d=d.dropna(subset=['low_access'])
    x,names=design(d,years,extension,binary)
    second=np.where(d.year>=2016,'post','pre') if binary else d.region_year
    fit=fit_fe(d[outcome].to_numpy(),x,[d.parish_id,second],d.parish_id,names)
    return fit,d

def main():
    raw,d,breaks=load_data()
    audit={'raw_rows':len(raw),'raw_parishes':int(raw.parish_id.nunique()),'waves':sorted(raw.year.unique().tolist()),'duplicate_keys':int(raw.duplicated(['parish_id','year']).sum()),'rows_with_missing_controls_or_distance':len(raw)-len(d),'complete_rows':len(d),'radius150_rows':int((d.min_distance_01<150).sum()),'radius150_parishes':int(d.loc[d.min_distance_01<150,'parish_id'].nunique()),'binary_missing_after_authors_cut':int(d.binary_presence.isna().sum()),'binary_breaks':breaks.tolist()}
    main_rows=[]; s16_rows=[]; contrasts=[]; extension_rows=[]; sensitivity=[]
    base=d[d.year==2001][['parish_id','public_primary_schools_per_thousand_kids_parish_level']].copy()
    baseline=base.set_index('parish_id')['public_primary_schools_per_thousand_kids_parish_level']
    cutoff=float(baseline.median()); d['baseline_school_access']=d.parish_id.map(baseline)
    d['low_access']=np.where(d.baseline_school_access.notna(),(d.baseline_school_access<=cutoff).astype(float),np.nan)
    audit['extension_baseline_median']=cutoff
    for (label,outcome),(expected,se,n) in zip(OUTCOMES.items(),EXPECTED):
        fit,sample=estimate(d,outcome)
        for name in fit.names:
            if name.startswith('presence'):
                main_rows.append({'outcome':label,'term':name,**fit.contrast({name:1})})
        if not 'road_density' in outcome:
            for post in [2016,2020]:
                if f'presence_{post}' in fit.names:
                    contrasts.append({'outcome':label,'contrast':f'{post} minus 2011',**fit.contrast({f'presence_{post}':1,'presence_2011':-1})})
        b,bs=estimate(d,outcome,binary=True); result=b.contrast({'treatment':1})
        s16_rows.append({'outcome':label,**result,'published_estimate':expected,'published_se':se,'published_n':n,'coefficient_matches_rounding':abs(result['estimate']-expected)<.00050001,'n_matches':result['n']==n,'se_matches_rounding':abs(result['se']-se)<.00050001})
    # One exploratory extension, specified before fitting: baseline primary-school access.
    # Primary endpoint: standardized public primary schools; comparator: public secondary.
    for label in ['Public primary schools','Public secondary schools']:
        outcome=OUTCOMES[label]; fit,sample=estimate(d,outcome,extension=True)
        for post in [2016,2020]:
            diff={f'presence_low_{post}':1,'presence_low_2011':-1}
            normal={f'presence_{post}':1,'presence_2011':-1}
            for group,weights in [('Above-median baseline access',normal),('At/below-median baseline access',{**normal,**diff}),('Difference between groups',diff)]:
                extension_rows.append({'outcome':label,'post_year':post,'group':group,**fit.contrast(weights)})
        for radius in [100,150,200]:
            f,s=estimate(d,outcome,radius=radius)
            for post in [2016,2020]: sensitivity.append({'outcome':label,'radius_km':radius,'post_year':post,**f.contrast({f'presence_{post}':1,'presence_2011':-1})})
    # Raw-unit robustness avoids interpreting year-specific standardization as levels.
    raw_extension=[]
    for label,outcome in [('Public primary schools','public_primary_schools_per_thousand_kids_parish_level'),('Public secondary schools','public_per_thousand_kid')]:
        f,ss=estimate(d,outcome,extension=True)
        for post in [2016,2020]:
            raw_extension.append({'outcome':label,'post_year':post,**f.contrast({f'presence_low_{post}':1,'presence_low_2011':-1})})
    pd.DataFrame(raw_extension).to_csv(OUT/'raw_unit_extension.csv',index=False)
    raw.groupby('year')[['public_primary_schools_per_thousand_kids_parish_level','public_per_thousand_kid','road_density']].agg(['mean','count']).to_csv(OUT/'raw_descriptive_trends.csv')
    tables={'main_coefficients':main_rows,'post2011_contrasts':contrasts,'s16_reconciliation':s16_rows,'baseline_access_extension':extension_rows,'radius_sensitivity':sensitivity}
    for name,rows in tables.items(): pd.DataFrame(rows).to_csv(OUT/f'{name}.csv',index=False)
    d[['parish_id','year','region','district','min_distance_01','presence','binary_presence','low_access']+list(OUTCOMES.values())].to_csv(OUT/'analysis_panel.csv.gz',index=False,compression='gzip')
    d[list(OUTCOMES.values())].isna().sum().rename('missing_rows').to_csv(OUT/'outcome_missingness.csv')
    audit['s16_coefficients_matching']=sum(x['coefficient_matches_rounding'] for x in s16_rows)
    audit['s16_samples_matching']=sum(x['n_matches'] for x in s16_rows)
    audit['s16_standard_errors_matching']=sum(x['se_matches_rounding'] for x in s16_rows)
    (OUT/'data_audit.json').write_text(json.dumps(audit,indent=2))
    manifest={'dataset_doi':'10.7910/DVN/TXSZDC','dataset_version':'1.0','python':platform.python_version(),'pandas':pd.__version__,'numpy':np.__version__,'data_sha256':hashlib.sha256(__import__('gzip').decompress((ROOT/'data/raw/political_data_merged_Dev_Econ_Paper.csv.gz').read_bytes())).hexdigest(),'inference':'Parish-cluster CR1; nested-FE small-sample correction; t(G-1) intervals','scope':'Selected public-goods replication; no survey/health-utilization replication'}
    (OUT/'run_manifest.json').write_text(json.dumps(manifest,indent=2))
    print(json.dumps(audit,indent=2)); print(pd.DataFrame(s16_rows)[['outcome','estimate','se','n','coefficient_matches_rounding','n_matches','se_matches_rounding']].to_string(index=False))
if __name__=='__main__': main()
