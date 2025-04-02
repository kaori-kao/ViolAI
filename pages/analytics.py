import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import json
import datetime
import math
from utils.data_service import DataService

# Initialize session state variables
if 'data_service' not in st.session_state:
    st.session_state.data_service = DataService()

# Page configuration
st.set_page_config(
    page_title="Analytics - Violin Coach",
    page_icon="🎻",
    layout="wide"
)

# Page title
st.title("🎻 Performance Analytics")
st.write("Detailed analysis of your violin practice performance over time")

# Get practice history
practice_history = st.session_state.data_service.get_practice_history(limit=50)

if not practice_history:
    st.info("You don't have any practice sessions yet. Start practicing to see your analytics!")
    st.markdown("[Go to Violin Coach](/) to start practicing")
else:
    # Convert to DataFrame for easier manipulation
    sessions_data = []
    for session in practice_history:
        session_dict = {
            "id": session.id,
            "date": session.start_time.strftime("%Y-%m-%d"),
            "day_of_week": session.start_time.strftime("%A"),
            "start_time": session.start_time.strftime("%H:%M"),
            "hour": session.start_time.hour,
            "duration_minutes": session.duration_seconds / 60 if session.duration_seconds else 0,
            "piece": session.piece_name,
            "posture_score": session.posture_score or 0,
            "bow_score": session.bow_direction_accuracy or 0,
            "rhythm_score": session.rhythm_score or 0,
            "overall_score": session.overall_score or 0
        }
        sessions_data.append(session_dict)
    
    sessions_df = pd.DataFrame(sessions_data)
    
    # Advanced analytics tabs
    tab1, tab2, tab3 = st.tabs(["Performance Trends", "Practice Patterns", "Skill Breakdown"])
    
    with tab1:
        st.subheader("Performance Trends")
        
        # Rolling average of scores
        if len(sessions_df) >= 3:
            # Add rolling average columns
            window_size = min(3, len(sessions_df))
            sessions_df_sorted = sessions_df.sort_values("date")
            sessions_df_sorted["posture_rolling"] = sessions_df_sorted["posture_score"].rolling(window=window_size).mean()
            sessions_df_sorted["bow_rolling"] = sessions_df_sorted["bow_score"].rolling(window=window_size).mean()
            sessions_df_sorted["rhythm_rolling"] = sessions_df_sorted["rhythm_score"].rolling(window=window_size).mean()
            sessions_df_sorted["overall_rolling"] = sessions_df_sorted["overall_score"].rolling(window=window_size).mean()
            
            # Create trend line chart
            fig = go.Figure()
            
            # Add individual data points
            fig.add_trace(go.Scatter(
                x=sessions_df_sorted["date"],
                y=sessions_df_sorted["overall_score"],
                mode="markers",
                name="Overall Score",
                marker=dict(size=8, color="rgba(147, 112, 219, 0.8)")
            ))
            
            # Add rolling average line
            fig.add_trace(go.Scatter(
                x=sessions_df_sorted["date"],
                y=sessions_df_sorted["overall_rolling"],
                mode="lines",
                name="3-Session Average",
                line=dict(width=3, color="rgba(147, 112, 219, 1.0)")
            ))
            
            fig.update_layout(
                title="Overall Performance Trend",
                xaxis_title="Practice Date",
                yaxis_title="Score (%)",
                height=500,
                hovermode="x unified",
                yaxis=dict(range=[0, 105])
            )
            
            st.plotly_chart(fig, use_container_width=True)
            
            # Create a radar chart for the most recent session vs average
            if not sessions_df.empty:
                latest_session = sessions_df.iloc[0]
                avg_scores = sessions_df.mean()
                
                categories = ["Posture", "Bow Technique", "Rhythm", "Overall"]
                latest_values = [
                    latest_session["posture_score"],
                    latest_session["bow_score"],
                    latest_session["rhythm_score"],
                    latest_session["overall_score"]
                ]
                avg_values = [
                    avg_scores["posture_score"],
                    avg_scores["bow_score"],
                    avg_scores["rhythm_score"],
                    avg_scores["overall_score"]
                ]
                
                fig = go.Figure()
                
                fig.add_trace(go.Scatterpolar(
                    r=latest_values,
                    theta=categories,
                    fill='toself',
                    name='Latest Session',
                    line_color='rgba(255, 140, 0, 0.8)'
                ))
                
                fig.add_trace(go.Scatterpolar(
                    r=avg_values,
                    theta=categories,
                    fill='toself',
                    name='Average Performance',
                    line_color='rgba(0, 191, 255, 0.8)'
                ))
                
                fig.update_layout(
                    title="Latest Session vs. Average Performance",
                    polar=dict(
                        radialaxis=dict(
                            visible=True,
                            range=[0, 100]
                        )
                    ),
                    showlegend=True,
                    height=500
                )
                
                st.plotly_chart(fig, use_container_width=True)
                
        else:
            st.info("You need at least 3 practice sessions to see performance trends.")
            
    with tab2:
        st.subheader("Practice Patterns")
        
        # Practice frequency by day of week
        day_order = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        day_counts = sessions_df["day_of_week"].value_counts().reindex(day_order).fillna(0)
        
        fig = px.bar(
            x=day_counts.index,
            y=day_counts.values,
            labels={"x": "Day of Week", "y": "Number of Sessions"},
            title="Practice Frequency by Day of Week",
            color=day_counts.values,
            color_continuous_scale="Viridis"
        )
        
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)
        
        # Practice duration by time of day
        sessions_df["hour_group"] = pd.cut(
            sessions_df["hour"],
            bins=[0, 6, 12, 18, 24],
            labels=["Night (0-6)", "Morning (6-12)", "Afternoon (12-18)", "Evening (18-24)"]
        )
        
        time_duration = sessions_df.groupby("hour_group")["duration_minutes"].mean().reset_index()
        
        fig = px.bar(
            time_duration,
            x="hour_group",
            y="duration_minutes",
            labels={"hour_group": "Time of Day", "duration_minutes": "Average Duration (min)"},
            title="Average Practice Duration by Time of Day",
            color="duration_minutes",
            color_continuous_scale="Viridis"
        )
        
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)
        
        # Practice consistency calendar heatmap
        if len(sessions_df) > 0:
            # Convert date strings to datetime
            sessions_df["date"] = pd.to_datetime(sessions_df["date"])
            
            # Get date range
            min_date = sessions_df["date"].min()
            max_date = sessions_df["date"].max()
            
            # Create a date range
            date_range = pd.date_range(start=min_date, end=max_date)
            full_date_df = pd.DataFrame({"date": date_range})
            
            # Count sessions per day
            session_counts = sessions_df.groupby("date").size().reset_index(name="count")
            
            # Merge to get all dates
            merged_df = pd.merge(full_date_df, session_counts, on="date", how="left").fillna(0)
            
            # Extract week number and day of week
            merged_df["weeknum"] = merged_df["date"].dt.isocalendar().week
            merged_df["dayofweek"] = merged_df["date"].dt.dayofweek
            merged_df["month"] = merged_df["date"].dt.month_name()
            
            # Create heatmap
            fig = px.imshow(
                merged_df.pivot_table(index="weeknum", columns="dayofweek", values="count", aggfunc="sum").fillna(0),
                labels=dict(x="Day of Week", y="Week", color="Sessions"),
                x=["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                color_continuous_scale="Viridis",
                title="Practice Consistency Calendar"
            )
            
            fig.update_layout(height=400)
            st.plotly_chart(fig, use_container_width=True)
            
            # Display practice streak information
            streaks = []
            current_streak = 0
            
            for date in date_range:
                day_count = merged_df[merged_df["date"] == date]["count"].values[0]
                if day_count > 0:
                    current_streak += 1
                else:
                    if current_streak > 0:
                        streaks.append(current_streak)
                    current_streak = 0
            
            if current_streak > 0:
                streaks.append(current_streak)
            
            if streaks:
                max_streak = max(streaks) if streaks else 0
                current_streak = streaks[-1] if streaks else 0
                
                col1, col2 = st.columns(2)
                with col1:
                    st.metric("Current Practice Streak", f"{current_streak} days")
                with col2:
                    st.metric("Longest Practice Streak", f"{max_streak} days")
            
    with tab3:
        st.subheader("Skill Breakdown")
        
        # Average scores by skill area
        skill_scores = {
            "Posture": sessions_df["posture_score"].mean(),
            "Bow Technique": sessions_df["bow_score"].mean(),
            "Rhythm": sessions_df["rhythm_score"].mean()
        }
        
        # Create a bar chart of skill breakdowns
        fig = px.bar(
            x=list(skill_scores.keys()),
            y=list(skill_scores.values()),
            labels={"x": "Skill Area", "y": "Average Score (%)"},
            title="Performance by Skill Area",
            color=list(skill_scores.values()),
            color_continuous_scale="RdYlGn",
            range_color=[0, 100]
        )
        
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)
        
        # Calculate areas for improvement
        lowest_skill = min(skill_scores, key=skill_scores.get)
        lowest_score = skill_scores[lowest_skill]
        
        # Recommendations based on skill scores
        st.subheader("Personalized Recommendations")
        
        recommendations = {
            "Posture": [
                "Focus on maintaining a straight back and relaxed shoulders",
                "Practice in front of a mirror to check your posture",
                "Try using a shoulder rest to improve comfort and stability",
                "Take regular breaks to prevent tension"
            ],
            "Bow Technique": [
                "Practice slow, controlled bow strokes",
                "Work on maintaining consistent bow pressure",
                "Focus on keeping the bow parallel to the bridge",
                "Practice bow distribution exercises"
            ],
            "Rhythm": [
                "Practice with a metronome",
                "Count out loud while playing",
                "Start with slower tempos and gradually increase speed",
                "Record yourself playing to identify rhythm issues"
            ]
        }
        
        col1, col2 = st.columns([1, 2])
        
        with col1:
            # Create gauge chart for overall score
            overall_avg = sessions_df["overall_score"].mean()
            
            fig = go.Figure(go.Indicator(
                mode="gauge+number",
                value=overall_avg,
                title={"text": "Overall Performance"},
                gauge={
                    "axis": {"range": [0, 100]},
                    "bar": {"color": "darkblue"},
                    "steps": [
                        {"range": [0, 50], "color": "lightgray"},
                        {"range": [50, 75], "color": "gray"},
                        {"range": [75, 100], "color": "lightblue"}
                    ],
                    "threshold": {
                        "line": {"color": "red", "width": 4},
                        "thickness": 0.75,
                        "value": 90
                    }
                }
            ))
            
            fig.update_layout(height=300)
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            st.write("### Focus Area: " + lowest_skill)
            st.write(f"Your average score: {lowest_score:.1f}%")
            
            st.write("Recommendations:")
            for rec in recommendations[lowest_skill]:
                st.markdown(f"- {rec}")
            
        # Progress to next level
        st.subheader("Progress to Next Level")
        
        # Define level thresholds
        levels = {
            "Beginner": 30,
            "Intermediate": 60,
            "Advanced": 85,
            "Master": 100
        }
        
        # Determine current level based on overall score
        overall_score = sessions_df["overall_score"].mean()
        current_level = "Beginner"
        next_level = "Intermediate"
        next_threshold = 30
        
        for level, threshold in sorted(levels.items(), key=lambda x: x[1]):
            if overall_score < threshold:
                next_level = level
                next_threshold = threshold
                break
            current_level = level
            
        if current_level == "Master":
            next_level = "Master+"
            next_threshold = 100
        
        # Calculate progress to next level
        prev_threshold = 0
        for level, threshold in sorted(levels.items(), key=lambda x: x[1]):
            if level == current_level:
                break
            prev_threshold = threshold
            
        progress_percentage = ((overall_score - prev_threshold) / (next_threshold - prev_threshold)) * 100
        progress_percentage = min(max(progress_percentage, 0), 100)
        
        # Display progress bar
        st.write(f"Current Level: **{current_level}** | Next Level: **{next_level}**")
        st.progress(progress_percentage / 100)
        st.write(f"You are {progress_percentage:.1f}% of the way to the next level")
        
        points_needed = next_threshold - overall_score
        if points_needed > 0:
            st.write(f"Improve your average score by {points_needed:.1f} points to reach {next_level} level")

# Navigation
st.markdown("---")
st.markdown("[Back to Violin Coach](/)  |  [View Practice History](/history)")

# Sidebar with tips for improvement
with st.sidebar:
    st.header("🎻 Tips for Improvement")
    
    st.info("""
    **Key Strategies to Improve:**
    
    1. **Regular Practice**: Consistency is more important than duration
    
    2. **Record and Review**: Use the app's history to track your progress
    
    3. **Focus on Fundamentals**: Master basic techniques before moving to advanced skills
    
    4. **Set Clear Goals**: Use specific, measurable goals for each practice session
    
    5. **Balance Skills**: Work on all areas (posture, bow technique, rhythm) equally
    """)
    
    # Add app logo/image
    st.image("violin_image.jpg", width=200)
    
    # Version info
    st.markdown("---")
    st.markdown("<h4 style='text-align: center;'>Violin Coach v2.0</h4>", unsafe_allow_html=True)
    st.markdown("<p style='text-align: center; color: gray;'>© 2025 Violin Coach</p>", unsafe_allow_html=True)