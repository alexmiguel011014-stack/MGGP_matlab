# import pandas as pd
# from mggp import MGGP

# if __name__ == '__main__':
#     df_train = pd.read_csv("F16GVT_Files/BenchmarkData/F16Data_FullMSine_Level3.csv").to_numpy()
#     # u_train, y_train = (df_train[:7372, :2], df_train[:7372, 2:5])
#     u_train, y_train = (df_train[:, :2], df_train[:, 2:5])
#     df_val = pd.read_csv("F16GVT_Files/BenchmarkData/F16Data_FullMSine_Level2_Validation.csv").to_numpy()
#     u_val, y_val = (df_val[:, :2], df_val[:, 2:5])
#     # print(len(u_train), len(y_train))

#     mggp = MGGP(inputs=u_train,
#                 outputs=y_train,
#                 validation=(u_val, y_val),
#                 nDelays=[1, 2, 3, 5, 10, 15, 25, 50],
#                 # nDelays=2,
#                 generations=50,
#                 evaluationMode="RMSE",
#                 k=100,
#                 evaluationType="MShooting")

#     mggp.run()

import pandas as pd
from mggp import MGGP

if __name__ == '__main__':
    path = "E:\matlab files\iTire road test data\Job1_2023_07_29_12_15_29_Mix\Tire_Features_extraidas2.csv"
    df_train = pd.read_csv(path)

    y_train = df_train[['Fx', 'Fy']].values
    u_train = df_train[['Mean_X', 'Variance_X', 'AbsMax_X', 'StdDev_X', 'Skewness_X', 'Kurtosis_X', 'Peak2Peak_X', 'RMS_X', 'CrestFactor_X', 'MarginFactor_X',
        'ShapeFactor_X', 'ImpulseFactor_X', 'MedianDev_X', 'MeanDev_X', 'Entropy_X', 'RootSumSquares_X', 'Energy_X', 'LogEnergy_X', 
        'Mean_Y', 'Variance_Y', 'AbsMax_Y', 'StdDev_Y', 'Skewness_Y', 'Kurtosis_Y', 'Peak2Peak_Y', 'RMS_Y', 'CrestFactor_Y', 'MarginFactor_Y',
        'ShapeFactor_Y', 'ImpulseFactor_Y', 'MedianDev_Y', 'MeanDev_Y', 'Entropy_Y', 'RootSumSquares_Y', 'Energy_Y', 'LogEnergy_Y', 
        'Mean_Z', 'Variance_Z', 'AbsMax_Z', 'StdDev_Z', 'Skewness_Z', 'Kurtosis_Z', 'Peak2Peak_Z', 'RMS_Z', 'CrestFactor_Z', 'MarginFactor_Z',
        'ShapeFactor_Z', 'ImpulseFactor_Z', 'MedianDev_Z', 'MeanDev_Z', 'Entropy_Z', 'RootSumSquares_Z', 'Energy_Z', 'LogEnergy_Z']].values

    mggp = MGGP(inputs=u_train,
                outputs=y_train,
                validation=(u_train, y_train),
                nDelays=[1, 2, 5, 10, 25, 50],
                generations=100,
                populationSize=200,
                evaluationMode="RMSE",
                k=100,
                evaluationType="MShooting",
                evaluationTypeTest="FreeRun"
                )

    mggp.run()
