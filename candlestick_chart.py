import pandas as pd
import plotly.graph_objects as go
from datetime import datetime

def read_and_filter_xauusd():
    """
    Reads the XAUUSD_M30.csv file and filters it for the date range 2019-11-01 to 2020-08-31.
    Also filters out weekend data to avoid gaps in the chart.
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

    # Filter out weekend data (Saturday=5, Sunday=6 in pandas weekday)
    filtered_df = filtered_df[filtered_df['datetime'].dt.weekday < 5]

    # Sort by datetime to ensure chronological order
    filtered_df = filtered_df.sort_values(by='datetime')

    return filtered_df

def create_candlestick_chart(data):
    """
    Creates and displays a candlestick chart from the provided data with no gaps for weekends.
    """
    # Reset the index to create a continuous x-axis without gaps
    data_reset = data.reset_index(drop=True)

    # Create the candlestick chart
    fig = go.Figure(data=go.Candlestick(
        x=data_reset.index,  # Use the continuous index instead of datetime
        open=data_reset['open'],
        high=data_reset['high'],
        low=data_reset['low'],
        close=data_reset['close'],
        name='XAUUSD'
    ))

    # Customize the chart layout
    fig.update_layout(
        title='XAUUSD 30-Minute Candlestick Chart (2019-11-01 to 2020-08-31)',
        xaxis_title='Time',
        yaxis_title='Price (USD)',
        xaxis_rangeslider_visible=False,  # Hide range slider for cleaner look
        width=1200,  # Set the width of the chart
        height=800,  # Set the height of the chart
    )

    # Add hover template to show the actual datetime
    fig.update_traces(
        hovertemplate='<b>%{customdata}</b><br>' +
                      'Open: %{open}<br>' +
                      'High: %{high}<br>' +
                      'Low: %{low}<br>' +
                      'Close: %{close}<extra></extra>',
        customdata=data_reset['datetime'].dt.strftime('%Y-%m-%d %H:%M:%S')  # Format datetime for hover
    )

    return fig

if __name__ == "__main__":
    # Execute the function and create the chart
    try:
        filtered_data = read_and_filter_xauusd()
        
        print(f"Creating candlestick chart for data from {filtered_data['datetime'].min()} to {filtered_data['datetime'].max()}")
        print(f"Total rows in filtered dataset: {len(filtered_data)}")
        
        # Create and display the candlestick chart
        chart = create_candlestick_chart(filtered_data)
        chart.show()
        
    except FileNotFoundError:
        print("Error: XAUUSD_M30.csv file not found in the current directory.")
    except Exception as e:
        print(f"An error occurred: {e}")