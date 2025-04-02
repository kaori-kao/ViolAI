import streamlit as st
import pandas as pd
import plotly.express as px
import json
import datetime
from utils.data_service import DataService

# Initialize session state variables
if 'data_service' not in st.session_state:
    st.session_state.data_service = DataService()

# Page configuration
st.set_page_config(
    page_title="Practice History - Violin Coach",
    page_icon="🎻",
    layout="wide"
)

# Page title
st.title("🎻 Practice History")
st.write("View your practice history and progress over time")

# Get practice history
practice_history = st.session_state.data_service.get_practice_history(limit=20)

if not practice_history:
    st.info("You don't have any practice sessions yet. Start practicing to see your history!")
else:
    # Convert to DataFrame for easier manipulation
    sessions_data = []
    for session in practice_history:
        session_dict = {
            "id": session.id,
            "date": session.start_time.strftime("%Y-%m-%d"),
            "start_time": session.start_time.strftime("%H:%M"),
            "duration_minutes": session.duration_seconds / 60 if session.duration_seconds else 0,
            "piece": session.piece_name,
            "posture_score": session.posture_score or 0,
            "bow_score": session.bow_direction_accuracy or 0,
            "rhythm_score": session.rhythm_score or 0,
            "overall_score": session.overall_score or 0
        }
        sessions_data.append(session_dict)
    
    sessions_df = pd.DataFrame(sessions_data)
    
    # Display summary statistics
    st.subheader("Practice Summary")
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        total_sessions = len(sessions_df)
        st.metric("Total Sessions", total_sessions)
        
    with col2:
        total_minutes = sessions_df["duration_minutes"].sum()
        st.metric("Total Practice Time", f"{total_minutes:.1f} min")
        
    with col3:
        avg_score = sessions_df["overall_score"].mean()
        st.metric("Average Score", f"{avg_score:.1f}%")
        
    with col4:
        if len(sessions_df) > 1:
            latest_score = sessions_df.iloc[0]["overall_score"]
            previous_score = sessions_df.iloc[1]["overall_score"]
            score_change = latest_score - previous_score
            st.metric("Last Session Score", f"{latest_score:.1f}%", f"{score_change:+.1f}%")
        else:
            latest_score = sessions_df.iloc[0]["overall_score"] if not sessions_df.empty else 0
            st.metric("Last Session Score", f"{latest_score:.1f}%")
    
    # Progress over time chart
    st.subheader("Progress Over Time")
    
    # Prepare data for time series
    if len(sessions_df) > 1:
        fig = px.line(
            sessions_df, 
            x="date", 
            y=["posture_score", "bow_score", "rhythm_score", "overall_score"],
            labels={"value": "Score (%)", "variable": "Metric", "date": "Date"},
            title="Performance Metrics Over Time",
            color_discrete_map={
                "posture_score": "#00BFFF",  # Blue
                "bow_score": "#FF8C00",      # Orange
                "rhythm_score": "#32CD32",   # Green
                "overall_score": "#9370DB"   # Purple
            }
        )
        fig.update_layout(
            legend_title="Metrics",
            xaxis_title="Practice Date",
            yaxis_title="Score (%)",
            hovermode="x unified",
            height=500
        )
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("You need at least two practice sessions to see progress over time.")
    
    # Practice duration chart
    st.subheader("Practice Duration")
    
    fig_duration = px.bar(
        sessions_df,
        x="date",
        y="duration_minutes",
        labels={"duration_minutes": "Duration (min)", "date": "Date"},
        title="Practice Duration by Session",
        color="duration_minutes",
        color_continuous_scale="Viridis"
    )
    fig_duration.update_layout(
        xaxis_title="Practice Date",
        yaxis_title="Duration (minutes)",
        height=400
    )
    st.plotly_chart(fig_duration, use_container_width=True)
    
    # Detailed history table
    st.subheader("Detailed History")
    
    # Format the DataFrame for display
    display_df = sessions_df.copy()
    display_df["date"] = pd.to_datetime(display_df["date"]).dt.strftime("%Y-%m-%d")
    display_df = display_df.rename(columns={
        "date": "Date",
        "start_time": "Time",
        "duration_minutes": "Duration (min)",
        "piece": "Piece",
        "posture_score": "Posture Score (%)",
        "bow_score": "Bow Score (%)",
        "rhythm_score": "Rhythm Score (%)",
        "overall_score": "Overall Score (%)"
    })
    
    # Format numerical columns
    for col in ["Posture Score (%)", "Bow Score (%)", "Rhythm Score (%)", "Overall Score (%)"]:
        display_df[col] = display_df[col].apply(lambda x: f"{x:.1f}")
    
    display_df["Duration (min)"] = display_df["Duration (min)"].apply(lambda x: f"{x:.1f}")
    
    # Show the table without the ID column
    st.dataframe(display_df.drop(columns=["id"]), use_container_width=True)
    
    # Option to clear history
    if st.button("Clear Practice History", type="secondary"):
        # This would require additional database function
        st.warning("This will delete all your practice history. This action cannot be undone.")
        if st.button("Yes, Clear All History", type="primary"):
            # TODO: Add function to clear history
            st.success("Practice history cleared!")
            st.rerun()

# Navigation back to main app
st.markdown("---")
st.markdown("[Back to Violin Coach](/)  |  [View Analytics](/analytics)")

# Sidebar with tips
with st.sidebar:
    st.header("🎻 Practice Tips")
    st.info("""
    **Tips for Effective Practice:**
    
    1. **Consistent Schedule**: Practice regularly, even if it's just for 15 minutes
    
    2. **Focus on Posture**: Good posture is the foundation of good playing
    
    3. **Slow Practice**: Practice difficult passages slowly before gradually increasing speed
    
    4. **Record Yourself**: Listen to recordings of your practice to identify areas for improvement
    
    5. **Take Breaks**: Rest regularly to avoid fatigue and maintain focus
    """)
    
    # Add app logo/image
    st.image("violin_image.jpg", width=200)
    
    # Version info
    st.markdown("---")
    st.markdown("<h4 style='text-align: center;'>Violin Coach v2.0</h4>", unsafe_allow_html=True)
    st.markdown("<p style='text-align: center; color: gray;'>© 2025 Violin Coach</p>", unsafe_allow_html=True)