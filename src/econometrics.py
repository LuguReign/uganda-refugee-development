"""Transparent fixed-effect OLS and parish-cluster CR1 inference.
Alternating projections avoid constructing thousands of parish dummy columns.
"""
from dataclasses import dataclass
import numpy as np
import pandas as pd
from scipy import linalg, stats


def absorb(values, groups, tol=1e-10, max_iter=10000):
    a = np.asarray(values, float).copy()
    codes = [pd.factorize(g)[0] for g in groups]
    for iteration in range(max_iter):
        prev = a.copy()
        for code in codes:
            counts = np.bincount(code)
            means = np.zeros((len(counts), a.shape[1]))
            np.add.at(means, code, a)
            a -= (means / counts[:, None])[code]
        if np.max(np.abs(a-prev)) < tol:
            return a, iteration+1
    raise RuntimeError('Fixed-effect absorption did not converge')

@dataclass
class Fit:
    beta: np.ndarray
    cov: np.ndarray
    names: list
    n: int
    clusters: int
    rank: int
    iterations: int
    condition: float
    def contrast(self, weights):
        w = np.array([weights.get(s,0) for s in self.names])
        estimate = float(w @ self.beta)
        se = float(np.sqrt(max(0, w @ self.cov @ w)))
        critical = stats.t.ppf(.975, self.clusters-1)
        return {'estimate':estimate,'se':se,'ci_low':estimate-critical*se,
                'ci_high':estimate+critical*se,
                'p_value':float(2*stats.t.sf(abs(estimate/se),self.clusters-1)) if se else np.nan,
                'n':self.n,'clusters':self.clusters}

def fit_fe(y, x, groups, cluster, names):
    a, iterations = absorb(np.column_stack([y,x]),groups)
    yr,xr = a[:,0],a[:,1:]
    norms = np.linalg.norm(xr,axis=0)
    active = np.flatnonzero(norms > 1e-9)
    scaled = xr[:,active]/norms[active]
    q,r,piv = linalg.qr(scaled,mode='economic',pivoting=True)
    rank = int(np.sum(np.abs(np.diag(r)) > 1e-9))
    kept = active[piv[:rank]]
    design = xr[:,kept]/norms[kept]
    b = linalg.lstsq(design,yr)[0]
    e = yr-design@b
    c = pd.factorize(cluster)[0]; G = c.max()+1
    scores = np.zeros((G,rank)); np.add.at(scores,c,design*e[:,None])
    bread = linalg.inv(design.T@design)
    # reghdfe convention: parish FE nested in the parish cluster are not
    # penalized again in CR1. Count nonredundant second FE plus intercept.
    g1 = pd.Series(groups[0]).nunique(); g2 = pd.Series(groups[1]).nunique()
    second = pd.Series(groups[1]).astype(str)
    if second.str.contains(':').all(): components=second.str.split(':').str[0].nunique()
    else: components=1
    fe_rank = g2-components+1
    correction=G/(G-1)*(len(e)-1)/(len(e)-rank-fe_rank)
    cov_scaled = bread@(scores.T@scores)@bread*correction
    beta = np.zeros(len(names)); covariance=np.zeros((len(names),len(names)))
    beta[kept]=b/norms[kept]
    covariance[np.ix_(kept,kept)]=cov_scaled/np.outer(norms[kept],norms[kept])
    return Fit(beta,covariance,names,len(e),G,rank,iterations,float(np.linalg.cond(design)))
