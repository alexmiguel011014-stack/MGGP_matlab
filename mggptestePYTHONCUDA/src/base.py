# -*- coding: utf-8 -*-
"""
Created on Apr 2023

@author: Henrique Castro

Modified for CUDA (CuPy) support: IndividualMISO and IndividualMIMO leastSquares
methods use cp.linalg.lstsq when ind._use_cuda=True, falling back to CPU if CuPy
is unavailable or no GPU is found.
"""

import pickle
from functools import partial
from abc import ABC, abstractmethod
from typing import List
import sys
import random
from deap import gp, creator, base, tools
import operator
import numpy as np
import re
import warnings
from sklearn.metrics import mean_squared_error, accuracy_score, log_loss
from numba import njit
from src.predictors import miso_OSA, miso_FreeRun, miso_MShooting, mimo_CLASSIFY, miso_FIR_INSTANT, mimo_FIR_INSTANT, miso_CLASSIFY
from src.predictors import mimo_OSA, mimo_FreeRun, mimo_MShooting, mimo_FIR_MShooting, mimo_FIR_FreeRun
from sklearn.preprocessing import LabelBinarizer
import warnings
warnings.filterwarnings('ignore')


def _cupy_lstsq(p, yd):
    """Solve p @ theta = yd on GPU using CuPy; returns numpy array."""
    import cupy as cp
    Pgpu = cp.asarray(p)
    ygpu = cp.asarray(yd)
    theta_gpu = cp.linalg.lstsq(Pgpu, ygpu, rcond=None)[0]
    return cp.asnumpy(theta_gpu)


def _roll(*args, i):
    return np.roll(*args, shift=i)

def sign(X1, X2):
    return np.sign(X1 - X2)


class Element(object):
    def __init__(self,
                 weights: tuple = (-1,),
                 nDelays: int | List = 3,
                 nInputs: int = 1,
                 nOutputs: int = 1,
                 nTerms: int = 10,
                 maxHeight: int = 5,
                 mode="MISO",
                 single_delay_only: bool = False,
                 operators=['mul', 'subtraction', 'sign']):

        self._pset: gp.PrimitiveSet = None
        self._toolbox: base.Toolbox = None
        self._mode = mode.upper()
        self._single_delay_only = single_delay_only

        if nInputs == 1 and nOutputs == 1:
            self._mode = "SISO"

        if self._mode == "FIR":
            self._nVar = nInputs
        elif self._mode == "SISO":
            self._nVar = 2
        else:
            self._nVar = nInputs + nOutputs

        if type(nDelays) is int:
            self._delays = np.arange(1, nDelays + 1)
        elif type(nDelays) is list:
            self._delays = nDelays

        self.operators = operators
        self.primitives_sets = {
            "mul": (operator.mul, 2),
            "sign": (sign, 2),
            "subtraction": (operator.sub, 2),
            "add": (operator.add, 2),
        }

        self.iniciatePrimitivesSets()

        self._weights = weights
        self._nTerms = nTerms
        self._nOutputs = nOutputs
        self._maxHeight = maxHeight

        creator.create("Program", gp.PrimitiveTree, fitness=None, pset=self.pset)
        creator.create("FitnessMin", base.Fitness, weights=self._weights)

        if self._mode == "MISO":
            creator.create("Individual", IndividualMISO, fitness=creator.FitnessMin)
        elif self._mode == "MIMO":
            creator.create("Individual", IndividualMIMO, fitness=creator.FitnessMin)
        elif self._mode == "SISO":
            creator.create("Individual", IndividualSISO, fitness=creator.FitnessMin)
        elif self._mode == "FIR":
            if nOutputs == 1:
                creator.create("Individual", IndividualFIR, fitness=creator.FitnessMin)
            else:
                creator.create("Individual", IndividualFIRMIMO, fitness=creator.FitnessMin)
        else:
            raise Exception("Choose a mode between:\nMISO, MIMO, FIR or SISO")
        self.iniciateToolbox()

    def getMode(self):
        return self._mode

    def iniciatePrimitivesSets(self):
        self._pset = gp.PrimitiveSet("main", self._nVar)
        for op in self.operators:
            if op in self.primitives_sets.keys():
                func, arity = self.primitives_sets[op]
                self._pset.addPrimitive(func, arity, name=op)
            else:
                raise ValueError(f"Operator '{op}' is not defined in primitives_sets.")
        if not self._single_delay_only:
            delays = [partial(_roll, i=i) for i in self._delays]
            for i, roll in zip(self._delays, delays):
                self._pset.addPrimitive(roll, 1, name=f'q{i}')

    def iniciateToolbox(self):
        def generate_terminal_only():
            terminal_index = random.randint(1, self._nVar)
            if self._mode == "FIR":
                terminal_name = f"u{terminal_index}"
            else:
                if terminal_index <= (self._nVar - self._nOutputs):
                    terminal_name = f"u{terminal_index}"
                else:
                    terminal_name = f"y{terminal_index}"
            terminal_node = self._pset.mapping[terminal_name]
            return gp.PrimitiveTree([terminal_node])

        self._toolbox = base.Toolbox()
        self._toolbox.register("_expr", self.genGrowLimitedNodes, pset=self._pset, min_depth=0, max_depth=self._maxHeight, max_nodes=20)
        self._toolbox.register("_program", tools.initIterate, creator.Program, self._toolbox._expr)

        if self._mode == "SISO":
            creator.create("Individual", IndividualSISO, fitness=creator.FitnessMin)
            self._toolbox.register("individual", tools.initRepeat, creator.Individual, self._toolbox._program, self._nTerms)
        elif self._mode == "MISO" or (self._mode == "FIR" and self._nOutputs == 1):
            self._toolbox.register("individual", tools.initRepeat, creator.Individual, self._toolbox._program, self._nTerms)
        elif self._mode == "MIMO" or (self._mode == "FIR" and self._nOutputs > 1):
            self._toolbox.register("_outputs", tools.initRepeat, list, self._toolbox._program, self._nTerms)
            self._toolbox.register("individual", tools.initRepeat, creator.Individual, self._toolbox._outputs, self._nOutputs)

        self._toolbox.register("population", tools.initRepeat, list, self._toolbox.individual)

    def genGrowLimitedNodes(self, pset, min_depth, max_depth, max_nodes):
        while True:
            expr = gp.genHalfAndHalf(pset, min_depth, max_depth)
            tree = gp.PrimitiveTree(expr)
            if len(tree) <= max_nodes:
                return expr

    @property
    def pset(self):
        return self._pset

    @property
    def toolbox(self):
        return self._toolbox

    def renameArguments(self, dictionary={'ARG0': 'y', 'ARG1': 'u'}):
        self._pset.renameArguments(**dictionary)

    def addPrimitive(self, *args):
        self._pset.addPrimitive(*args)

    def buildModelFromList(self, listString):
        model = creator.Individual()
        if self._mode == "SISO":
            for string in listString:
                model.append(gp.PrimitiveTree.from_string(string, self.pset))
        if self._mode == "MISO" or self._mode == "FIR" and self._nOutputs == 1:
            for string in listString:
                model.append(gp.PrimitiveTree.from_string(string, self.pset))
        if self._mode == "MIMO" or (self._mode == "FIR" and self._nOutputs > 1):
            for out in listString:
                aux = [gp.PrimitiveTree.from_string(string, self.pset) for string in out]
                model.append(aux)
        return model

    def buildRandomModel(self):
        return self._toolbox.individual()

    def compileModel(self, model):
        if self._mode == 'SISO':
            model._funcs = [gp.compile(tree, self.pset) for tree in model]
        elif self._mode == 'MISO' or self._mode == "FIR" and self._nOutputs == 1:
            model._funcs = [gp.compile(tree, self.pset) for tree in model]
        elif self._mode == 'MIMO' or (self._mode == "FIR" and self._nOutputs > 1):
            model._funcs = [[gp.compile(tree, self.pset) for tree in out] for out in model]
        self._setModelLagMax(model)

    def _setModelLagMax(self, model):
        def checkbranch(branch):
            if branch == []: return
            if branch[-1][2] == branch[-1][1]:
                del branch[-1]
                if branch == []: return
                branch[-1][2] += 1
                return checkbranch(branch)

        def checkOut(output):
            treelags = []
            for tree in output:
                i = 0
                lagMax = 0
                branches = []
                count = 0
                while i < len(tree):
                    if re.search("q\d", tree[i].name):
                        count += int(tree[i].name[1:])
                    elif type(tree[i]) == gp.Primitive:
                        branches.append([count, tree[i].arity, 0])
                        count = 0
                    elif type(tree[i]) == gp.Terminal:
                        if branches == []:
                            lag = count
                            model._terminals += str(tree[i].value) + '[i-%d] * ' % (count + 1)
                        else:
                            branches[-1][2] += 1
                            lag = count + sum([item[0] for item in branches])
                            model._terminals += tree[i].value + '[i-%d] * ' % (lag + 1)
                        if lag > lagMax:
                            lagMax = lag
                        count = 0
                        checkbranch(branches)
                    i += 1
                treelags.append(lagMax)
                model._terminals += '\n'
            model._terminals += '\n'
            return max(treelags)

        if self._mode == "SISO":
            model.lagMax = checkOut(model)
        elif self._mode == "MISO" or (self._mode == "FIR" and self._nOutputs == 1):
            model.lagMax = checkOut(model)
        elif self._mode == "MIMO" or (self._mode == "FIR" and self._nOutputs > 1):
            aux = []
            for i, out in enumerate(model):
                model._terminals += 'Output %d:\n\n' % (i + 1)
                aux.append(checkOut(out))
            model.lagMax = max(aux)

    def save(self, filename, dictionary):
        with open(filename, 'wb') as f:
            pickle.dump(dictionary, f)

    def load(self, filename):
        with open(filename, 'rb') as f:
            return pickle.load(f)


class Individual(list):
    def __init__(self, data=[]):
        super().__init__(data)
        self._funcs = []
        self._lagMax = None
        self._theta = np.array([])
        self._terminals = ''
        self._nTerms = 0
        self._logistic_model = None
        self._label_binarizer = None
        self._use_cuda = False

    @property
    def theta(self):
        return self._theta

    @theta.setter
    def theta(self, theta):
        self._theta = theta

    @property
    def lagMax(self):
        return self._lagMax

    @lagMax.setter
    def lagMax(self, lag):
        self._lagMax = lag

    @abstractmethod
    def makeRegressors(self, y, u):
        pass

    @abstractmethod
    def leastSquares(self, y, u):
        pass

    def constrained_least_squares(self, y, u, p, constraints=None):
        yd = y[self.lagMax + 1:]
        theta_ls = np.linalg.lstsq(p, yd, rcond=None)[0]
        if constraints is None:
            self._theta = theta_ls
            return self._theta
        S = constraints['S']
        c = constraints['c'].reshape(-1, 1)
        pT_p = p.T @ p
        pT_p_inv = np.linalg.pinv(pT_p)
        term1 = pT_p_inv @ S.T
        term2 = np.linalg.pinv(S @ pT_p_inv @ S.T)
        term3 = S @ theta_ls - c
        theta_cls = theta_ls - term1 @ term2 @ term3
        self._theta = theta_cls
        return self._theta

    def identify_term_clusters(self, y, u):
        p = self.makeRegressors(y, u)
        if not isinstance(p, np.ndarray):
            raise TypeError("identify_term_clusters currently supports scalar-output regressors matrices (SISO/MISO/FIR).")
        n_terms = p.shape[1]
        clusters = {"bias": [], "linear_output": [], "linear_input": [], "nonlinear_y": [], "nonlinear_u": [], "cross_terms": [], "phi_terms": []}
        for term_index in range(n_terms):
            clusters[self._classify_term(term_index)].append(term_index)
        return clusters

    @staticmethod
    def _node_is_q(node) -> bool:
        return isinstance(node, gp.Primitive) and re.fullmatch(r"q\d+", getattr(node, "name", "")) is not None

    @staticmethod
    def _node_is_phi(node) -> bool:
        return isinstance(node, gp.Primitive) and getattr(node, "name", "") in ("subtraction", "sign")

    @staticmethod
    def _terminal_value_str(term) -> str:
        v = getattr(term, "value", None)
        if v is None:
            v = getattr(term, "name", "")
        return str(v)

    def _tree_contains_var(self, tree, var_prefix: str) -> bool:
        for node in tree:
            if isinstance(node, gp.Terminal) and self._terminal_value_str(node).startswith(var_prefix):
                return True
        return False

    def _tree_has_only_q_and_var(self, tree, var_prefix: str, require_at_least_one_q: bool = True) -> bool:
        q_count = 0
        term_count = 0
        for node in tree:
            if isinstance(node, gp.Primitive):
                if self._node_is_q(node):
                    q_count += 1
                else:
                    return False
            elif isinstance(node, gp.Terminal):
                term_count += 1
                if not self._terminal_value_str(node).startswith(var_prefix):
                    return False
            else:
                return False
        if term_count != 1:
            return False
        if require_at_least_one_q and q_count == 0:
            return False
        return True

    def _is_linear_term(self, tree_str: str = None, tree=None) -> bool:
        if tree is None:
            return False
        return (
            self._tree_has_only_q_and_var(tree, "y", require_at_least_one_q=True)
            or self._tree_has_only_q_and_var(tree, "u", require_at_least_one_q=True)
        )

    def _classify_term(self, term_index):
        if term_index == 0:
            return 'bias'
        if hasattr(self, '_funcs') and len(self._funcs) > term_index - 1:
            tree_str = str(self[term_index - 1]).lower()
            if 'subtraction' in tree_str or 'sign' in tree_str:
                return 'phi_terms'
            if 'y' in tree_str and 'u' not in tree_str:
                if self._is_linear_term(tree_str):
                    return 'linear_output'
                else:
                    return 'nonlinear_y'
            elif 'u' in tree_str and 'y' not in tree_str:
                if self._is_linear_term(tree_str):
                    return 'linear_input'
                else:
                    return 'nonlinear_u'
            elif 'y' in tree_str and 'u' in tree_str:
                return 'cross_terms'
        return 'phi_terms'

    def _is_linear_term(self, tree_str):
        non_linear_ops = ['sign', 'subtraction', 'mul(mul', 'mul(q', 'mul(']
        return not any(op in tree_str for op in non_linear_ops)

    def hysteretic_constrained_ls(self, y, u, tol=1e-8):
        clusters = self.identify_term_clusters(y, u)
        constraints = []
        p = self.makeRegressors(y, u)
        length_model = p.shape[1]
        if clusters["bias"]:
            s = np.zeros(length_model)
            s[clusters["bias"]] = 1.0
            constraints.append((s, 0.0))
        if not clusters["linear_output"]:
            raise ValueError("No linear output term found.")
        s = np.zeros(length_model)
        s[clusters["linear_output"]] = 1.0
        constraints.append((s, 1.0))
        for cluster_name in ("linear_input", "cross_terms", "nonlinear_y", "nonlinear_u", 'phi_terms'):
            idxs = clusters[cluster_name]
            if not idxs:
                continue
            s = np.zeros(length_model)
            s[idxs] = 1.0
            constraints.append((s, 0.0))
        S = np.vstack([c[0] for c in constraints])
        c = np.array([c[1] for c in constraints])
        return self.constrained_least_squares(y, u, p, {"S": S, "c": c})

    def predict(self, mode="OSA", *args):
        if mode == "OSA":
            return mimo_OSA(self, *args)
        if mode == "FreeRun":
            return mimo_FreeRun(self, *args)
        if mode == "MShooting":
            return mimo_MShooting(self, *args)
        else:
            raise Exception("Choose a mode between: OSA, FreeRun, MShooting")

    def score(self, yd, yp, mode="MSE"):
        from sklearn.metrics import mean_squared_error
        if mode not in ["MSE", "NMSE", "MAPE", "RMSE"]:
            raise ValueError("Choose a valid metric: MSE, NMSE, MAPE or RMSE")
        if mode == "MSE":
            return self._compute_metric_per_output(yd, yp, mean_squared_error)
        if mode == "MAPE":
            return self._mape(yd, yp)
        if mode == "RMSE":
            return self._compute_metric_per_output(yd, yp, lambda y_true, y_pred: np.sqrt(mean_squared_error(y_true, y_pred)))
        if mode == "NMSE":
            return self._compute_metric_per_output(yd, yp, self._nmse_variance)

    def _mape(self, yd, yp):
        diff = np.abs(yd - yp)
        denominator = np.abs(np.max(yd, axis=0) - np.min(yd, axis=0))
        safe_denominator = np.where(denominator == 0, np.nan, denominator)
        mape_per_output = 100 * np.nanmean(diff / safe_denominator, axis=0)
        return np.nanmean(mape_per_output)

    def _compute_metric_per_output(self, yd, yp, metric_func):
        return np.mean([metric_func(yd[:, i], yp[:, i]) for i in range(yd.shape[1])])

    def _nmse_variance(self, y_true, y_pred):
        from sklearn.metrics import mean_squared_error
        mse = mean_squared_error(y_true, y_pred)
        variance = np.var(y_true)
        return mse / variance if variance != 0 else mse

    def predict_proba(self, mode="INSTANT", *args):
        def one_hot_argmax(x):
            result = np.zeros_like(x)
            result[np.argmax(x)] = 1
            return result
        def softmax(x):
            e_x = np.exp(x - np.max(x))
            return e_x / e_x.sum()
        if mode == "INSTANT":
            X_regressors, y_true = mimo_CLASSIFY(self, *args)
        elif mode == "MShooting":
            X_regressors, y_true = mimo_MShooting(self, *args)
        else:
            raise Exception("Choose a mode between: INSTANT")
        if self._logistic_model is not None:
            pred_one_hot_encode = np.array([one_hot_argmax(softmax(x)) for x in X_regressors])
            return pred_one_hot_encode, y_true
        else:
            raise Exception("Logistic regression model not trained!")

    def predict_classes(self, mode="INSTANT", *args):
        predicted_classes, y_true = self.predict_proba(mode, *args)
        return predicted_classes, y_true

    def score_classification(self, yd, yp, mode="accuracy"):
        if mode == "accuracy":
            return accuracy_score(yd, yp)
        elif mode == "log_loss":
            return log_loss(yd, yp)
        elif mode == "f1_macro":
            from sklearn.metrics import f1_score
            return f1_score(yd, yp, average='macro')
        else:
            raise ValueError("Choose a valid metric: accuracy, log_loss, f1_macro")

    @abstractmethod
    def model2List(self):
        pass

    def to_equation(self):
        def checkbranch(branch):
            if branch == []: return
            if branch[-1][2] == branch[-1][1]:
                del branch[-1]
                if branch == []: return
                branch[-1][2] += 1
                return checkbranch(branch)

        def checkOut():
            string = ''
            for k, program in enumerate(self):
                string += 'Output %d:\n\n' % (k + 1)
                string += f'{self.theta[k][0]:.5e} + \n'
                for j, tree in enumerate(program):
                    i = 0
                    branches = []
                    count = 0
                    string += f'{self.theta[k][j + 1]:.5e} * '
                    while i < len(tree):
                        if re.search("q\d", tree[i].name):
                            count += int(tree[i].name[1:])
                        elif type(tree[i]) == gp.Primitive:
                            branches.append([count, tree[i].arity, 0])
                            count = 0
                        elif type(tree[i]) == gp.Terminal:
                            if branches == []:
                                lag = count
                                string += str(tree[i].value) + '[i-%d] * ' % (count + 1)
                            else:
                                branches[-1][2] += 1
                                lag = count + sum([item[0] for item in branches])
                                string += tree[i].value + '[i-%d] * ' % (lag + 1)
                            count = 0
                            checkbranch(branches)
                        i += 1
                    string = string[:-2] + '+ \n'
                string += '\n'
            return string

        string = checkOut()
        return string


@njit
def theta_miso(p, yd):
    return np.linalg.inv(p.T @ p) @ p.T @ yd


def theta_mimo(p, yd):
    return np.linalg.lstsq(p, yd, rcond=None)[0]


@njit
def theta_fir(p, yd):
    return np.linalg.inv(p.T @ p) @ p.T @ yd


class IndividualSISO(Individual):
    def __init__(self, data=[]):
        super().__init__(data)

    def predict(self, mode="OSA", *args):
        if mode == "OSA":
            return miso_OSA(self, *args)
        if mode == "FreeRun":
            return miso_FreeRun(self, *args)
        if mode == "MShooting":
            return miso_MShooting(self, *args)
        else:
            raise Exception("Choose a mode between: OSA, FreeRun, MShooting")

    def makeRegressors(self, y, u):
        if len(y.shape) == 1:
            y = y.reshape(-1, 1)
        if len(u.shape) == 1:
            u = u.reshape(-1, 1)
        listV = [y[:-1].reshape(-1, 1), u[:-1].reshape(-1, 1)]
        p = np.ones((y.shape[0] - self.lagMax - 1, len(self) + 1))
        for i in range(len(self)):
            func = self._funcs[i]
            out = func(*listV)
            p[:, i + 1] = out.reshape(-1)[self.lagMax:]
        return p

    def leastSquares(self, y, u):
        p = self.makeRegressors(y, u)
        yd = y[self.lagMax + 1:]
        if getattr(self, '_use_cuda', False):
            try:
                self._theta = _cupy_lstsq(p, yd)
            except Exception:
                self._theta = np.linalg.lstsq(p, yd, rcond=None)[0]
        else:
            self._theta = np.linalg.lstsq(p, yd, rcond=None)[0]
        if len(self._theta.shape) == 1:
            self._theta = self._theta.reshape(-1, 1)
        return self._theta

    def __str__(self):
        string = ''.join('%s\n' * len(self)) % tuple([str(tree) for tree in self])
        return '1\n' + string

    def model2List(self):
        return [str(tree) for tree in self]


class IndividualMISO(Individual):
    def __init__(self, data=[]):
        super().__init__(data)

    def predict(self, mode="OSA", *args):
        if mode == "OSA":
            return miso_OSA(self, *args)
        if mode == "FreeRun":
            return miso_FreeRun(self, *args)
        if mode == "MShooting":
            return miso_MShooting(self, *args)
        else:
            raise Exception("Choose a mode between: OSA, FreeRun, MShooting")

    def makeRegressors(self, y, u):
        if len(y.shape) == 1:
            y = y.reshape(-1, 1)
        if len(u.shape) == 1:
            u = u.reshape(-1, 1)
        if y.shape[1] > 1:
            raise Exception('Wrong number of outputs.')
        is_classification = bool(getattr(self, "_logistic_model", False))
        listV = [y.reshape(-1, 1)] if is_classification else [y[:-1].reshape(-1, 1)]
        for v in u.T:
            listV.append(v.reshape(-1, 1) if is_classification else v[:-1].reshape(-1, 1))
        n_samples = y.shape[0] - self.lagMax if is_classification else y.shape[0] - self.lagMax - 1
        p = np.ones((n_samples, len(self) + 1))
        for i in range(len(self)):
            func = self._funcs[i]
            out = func(*listV)
            p[:, i + 1] = out.reshape(-1)[self.lagMax:]
        return p

    def leastSquares(self, y, u):
        p = self.makeRegressors(y, u)
        is_classification = bool(getattr(self, "_logistic_model", False))
        offset = 0 if is_classification else 1
        yd = y[self.lagMax + offset:]
        if getattr(self, '_use_cuda', False):
            try:
                self._theta = _cupy_lstsq(p, yd)
            except Exception:
                # Fallback: use numpy lstsq (bypass Numba theta_miso for compatibility)
                self._theta = np.linalg.lstsq(p, yd, rcond=None)[0]
        else:
            self._theta = theta_miso(p, yd)
        if len(self._theta.shape) == 1:
            self._theta = self._theta.reshape(-1, 1)
        return self._theta

    def __str__(self):
        string = ''.join('%s\n' * len(self)) % tuple([str(tree) for tree in self])
        return '1\n' + string

    def model2List(self):
        return [str(tree) for tree in self]


class IndividualMIMO(Individual):
    def __init__(self, data=[]):
        super().__init__(data)

    def makeRegressors(self, y, u):
        if len(y.shape) == 1:
            y = y.reshape(-1, 1)
        if len(u.shape) == 1:
            u = u.reshape(-1, 1)
        if y.shape[1] == 1:
            raise Exception('Wrong number of outputs.')
        is_classification = bool(getattr(self, "_logistic_model", False))
        listV = []
        for v in y.T:
            listV.append(v.reshape(-1, 1) if is_classification else v[:-1].reshape(-1, 1))
        for v in u.T:
            listV.append(v.reshape(-1, 1) if is_classification else v[:-1].reshape(-1, 1))
        P = []
        for o in range(len(self)):
            n_samples = y.shape[0] - self.lagMax if is_classification else y.shape[0] - self.lagMax - 1
            p = np.ones((n_samples, len(self[o]) + 1))
            for i in range(len(self[o])):
                func = self._funcs[o][i]
                out = func(*listV)
                p[:, i + 1] = out.reshape(-1)[self.lagMax:]
            P.append(p)
        return P

    def leastSquares(self, y, u):
        if len(y.shape) == 1:
            y = y.reshape(-1, 1)
        if len(u.shape) == 1:
            u = u.reshape(-1, 1)
        P = self.makeRegressors(y, u)
        is_classification = bool(getattr(self, "_logistic_model", False))
        offset = 0 if is_classification else 1
        y_slice = y[self.lagMax + offset:, :]

        if getattr(self, '_use_cuda', False):
            try:
                self._theta = np.array([
                    _cupy_lstsq(P[o], y_slice[:, o])
                    for o in range(len(P))
                ])
                return self._theta
            except Exception:
                pass  # fallback to CPU

        self._theta = np.array([theta_mimo(P[o], y_slice[:, o]) for o in range(len(P))])
        return self._theta

    def __str__(self):
        string = ''
        i = 1
        for out in self:
            string += 'Output %d:\n\n1\n' % (i)
            for tree in out:
                string += str(tree) + '\n'
            i += 1
            string += '\n'
        return string

    def model2List(self):
        return [[str(tree) for tree in out] for out in self]


class IndividualFIR(Individual):
    def __init__(self, data=[]):
        super().__init__(data)

    def predict(self, mode="OSA", *args):
        if mode == "OSA":
            return miso_OSA(self, *args)
        if mode == "INSTANT":
            return miso_FIR_INSTANT(self, *args)
        if mode == "FreeRun":
            return miso_FreeRun(self, *args)
        if mode == "MShooting":
            return miso_MShooting(self, *args)
        else:
            raise Exception("Choose a mode between: OSA, INSTANT, FreeRun, MShooting")

    def makeRegressors(self, y, u, align="OSA"):
        if len(u.shape) == 1:
            u = u.reshape(-1, 1)
        if align not in ("OSA", "INSTANT"):
            raise ValueError("align must be 'OSA' or 'INSTANT'")
        listV = []
        if align == "OSA":
            for v in u.T:
                listV.append(v[:-1].reshape(-1, 1))
            n_samples = u.shape[0] - self.lagMax - 1
        else:
            for v in u.T:
                listV.append(v.reshape(-1, 1))
            n_samples = u.shape[0] - self.lagMax
        if n_samples <= 0:
            raise ValueError("Not enough samples.")
        p = np.ones((n_samples, len(self) + 1))
        for i in range(len(self)):
            func = self._funcs[i]
            out = func(*listV)
            p[:, i + 1] = out.reshape(-1)[self.lagMax:]
        return p

    def leastSquares(self, y, u, align="OSA"):
        p = self.makeRegressors(y, u, align=align)
        if np.linalg.cond(p, -2) < 1e-10:
            raise np.linalg.LinAlgError('Ill conditioned regressors matrix!')
        yd = y[self.lagMax + 1:] if align == "OSA" else y[self.lagMax:]
        self._theta = theta_fir(p, yd)
        if len(self._theta.shape) == 1:
            self._theta = self._theta.reshape(-1, 1)
        return self._theta

    def __str__(self):
        string = ''.join('%s\n' * len(self)) % tuple([str(tree) for tree in self])
        return '1\n' + string

    def model2List(self):
        return [str(tree) for tree in self]


class IndividualFIRMIMO(Individual):
    def __init__(self, data=[]):
        super().__init__(data)

    def makeRegressors(self, y, u, align="OSA"):
        if len(u.shape) == 1:
            u = u.reshape(-1, 1)
        if align not in ("OSA", "INSTANT"):
            raise ValueError("align must be 'OSA' or 'INSTANT'")
        listV = []
        if align == "OSA":
            for v in u.T:
                listV.append(v[:-1].reshape(-1, 1))
            n_samples = u.shape[0] - self.lagMax - 1
        else:
            for v in u.T:
                listV.append(v.reshape(-1, 1))
            n_samples = u.shape[0] - self.lagMax
        if n_samples <= 0:
            raise ValueError("Not enough samples.")
        P = []
        for o in range(len(self)):
            p = np.ones((n_samples, len(self[o]) + 1))
            for i in range(len(self[o])):
                func = self._funcs[o][i]
                out = func(*listV)
                p[:, i + 1] = out.reshape(-1)[self.lagMax:]
            P.append(p)
        return P

    def leastSquares(self, y, u, align="OSA"):
        P = self.makeRegressors(y, u, align=align)
        y_slice = y[self.lagMax + 1:, :] if align == "OSA" else y[self.lagMax:, :]
        self._theta = np.array([theta_mimo(P[o], y_slice[:, o]) for o in range(len(P))])
        return self._theta

    def predict(self, mode="OSA", *args):
        if mode == "OSA":
            return mimo_OSA(self, *args)
        if mode == "INSTANT":
            return mimo_FIR_INSTANT(self, *args)
        if mode == "FreeRun":
            return mimo_FIR_FreeRun(self, *args)
        if mode == "MShooting":
            return mimo_FIR_MShooting(self, *args)
        else:
            raise Exception("Choose a mode between: OSA, INSTANT, FreeRun, MShooting")

    def __str__(self):
        string = ''
        i = 1
        for out in self:
            string += 'Output %d:\n\n1\n' % (i)
            for tree in out:
                string += str(tree) + '\n'
            i += 1
            string += '\n'
        return string

    def model2List(self):
        return [[str(tree) for tree in out] for out in self]
