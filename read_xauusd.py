import pandas as pd
from datetime import datetime

def read_and_filter_xauusd():
    """
    Reads the XAUUSD_M30.csv file and filters it for the date range 2019-11-01 to 2020-08-31.
    """
    # Read the CSV file
    df = pd.read_csv('XAUUSD_M30.csv', header=None)
    
    # Assuming the first column contains datetime information
    # Column names based on typical forex data: datetime, open, high, low, close, volume
    df.columns = ['datetime', 'open', 'high', 'low', 'close', 'volume']
    
    # Convert the datetime column to pandas datetime
    df['datetime'] = pd.to_datetime(df['datetime'])
    
    # Define the start and end dates for filtering
    start_date = datetime(2019, 11, 1)
    end_date = datetime(2020, 8, 31)
    
    # Filter the dataframe to the specified date range
    filtered_df = df[(df['datetime'] >= start_date) & (df['datetime'] <= end_date)]
    
    # Sort by datetime to ensure chronological order
    filtered_df = filtered_df.sort_values(by='datetime')
    
    return filtered_df

if __name__ == "__main__":
    # Execute the function and display the results
    try:
        filtered_data = read_and_filter_xauusd()
        
        print(f"Showing data from {filtered_data['datetime'].min()} to {filtered_data['datetime'].max()}")
        print(f"Total rows in filtered dataset: {len(filtered_data)}")
        print("\nFirst 10 rows:")
        print(filtered_data.head(10))
        print("\nLast 10 rows:")
        print(filtered_data.tail(10))
        
    except FileNotFoundError:
        print("Error: XAUUSD_M30.csv file not found in the current directory.")
    except Exception as e:
        print(f"An error occurred: {e}")