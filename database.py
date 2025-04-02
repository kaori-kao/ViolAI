import os
import time
import datetime
import json
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Text, event
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from sqlalchemy.pool import QueuePool
from sqlalchemy.exc import OperationalError, DisconnectionError

# Get database URL from environment variables and ensure it's properly formatted
database_url = os.environ.get('DATABASE_URL')

# If the URL starts with 'postgres://', change it to 'postgresql://' for SQLAlchemy 1.4+
if database_url and database_url.startswith('postgres://'):
    database_url = database_url.replace('postgres://', 'postgresql://', 1)

print(f"Connecting to database: {database_url.split('@')[0].replace('://', '://****:****@') if database_url else 'None'}")

# Configure connection pool with retry logic
def get_engine():
    engine = create_engine(
        database_url,
        pool_size=5,
        max_overflow=10,
        pool_timeout=30,
        pool_recycle=1800,  # Recycle connections after 30 minutes
        pool_pre_ping=True,  # Verify connections before using them
        connect_args={"connect_timeout": 10}  # Connect timeout in seconds
    )
    
    # Add event listener to handle disconnections
    @event.listens_for(engine, "connect")
    def connect(dbapi_connection, connection_record):
        connection_record.info['pid'] = os.getpid()
    
    @event.listens_for(engine, "checkout")
    def checkout(dbapi_connection, connection_record, connection_proxy):
        pid = os.getpid()
        if connection_record.info['pid'] != pid:
            connection_record.connection = connection_proxy.connection = None
            raise DisconnectionError(
                "Connection record belongs to pid %s, "
                "attempting to check out in pid %s" %
                (connection_record.info['pid'], pid)
            )
    
    return engine

# Create SQLAlchemy engine and session with connection pooling
engine = get_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Helper function to retry database operations
def retry_operation(operation, max_retries=3, retry_delay=1):
    """Retry a database operation with exponential backoff"""
    retries = 0
    while retries < max_retries:
        try:
            return operation()
        except (OperationalError, DisconnectionError) as e:
            retries += 1
            if retries >= max_retries:
                raise
            print(f"Database connection error, retrying ({retries}/{max_retries}): {e}")
            time.sleep(retry_delay * (2 ** (retries - 1)))  # Exponential backoff

# Create base class for models
Base = declarative_base()

class User(Base):
    """User model for storing user data"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    # Relationships
    practice_sessions = relationship("PracticeSession", back_populates="user")
    calibration_profiles = relationship("CalibrationProfile", back_populates="user")
    
    def __repr__(self):
        return f"<User {self.username}>"

class PracticeSession(Base):
    """Model for storing practice session data"""
    __tablename__ = "practice_sessions"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    start_time = Column(DateTime, default=datetime.datetime.utcnow)
    end_time = Column(DateTime, nullable=True)
    duration_seconds = Column(Integer, nullable=True)
    piece_name = Column(String, default="Twinkle Twinkle Little Star")
    
    # Metrics for the session
    posture_score = Column(Float, nullable=True)
    bow_direction_accuracy = Column(Float, nullable=True)
    rhythm_score = Column(Float, nullable=True)
    overall_score = Column(Float, nullable=True)
    notes = Column(Text, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="practice_sessions")
    events = relationship("PracticeEvent", back_populates="session")
    
    def __repr__(self):
        return f"<PracticeSession {self.id}: {self.piece_name}>"

class PracticeEvent(Base):
    """Model for storing specific events during a practice session"""
    __tablename__ = "practice_events"
    
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("practice_sessions.id"))
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    event_type = Column(String)  # 'posture_correction', 'bow_direction_change', 'rhythm_progress'
    event_data = Column(Text)    # JSON-serialized data specific to the event
    
    # Relationships
    session = relationship("PracticeSession", back_populates="events")
    
    def __repr__(self):
        return f"<PracticeEvent {self.id}: {self.event_type}>"

class CalibrationProfile(Base):
    """Model for storing calibration profiles"""
    __tablename__ = "calibration_profiles"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String, default="Default Profile")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    is_active = Column(Boolean, default=True)
    calibration_data = Column(Text)  # JSON-serialized calibration data
    
    # Relationships
    user = relationship("User", back_populates="calibration_profiles")
    
    def __repr__(self):
        return f"<CalibrationProfile {self.id}: {self.name}>"

# Create tables in the database
Base.metadata.create_all(bind=engine)

def get_db():
    """Create a new database session with retry logic"""
    for retry in range(3):  # Try up to 3 times
        try:
            db = SessionLocal()
            try:
                # Test the connection
                db.execute("SELECT 1")
                yield db
                break
            except Exception:
                if retry < 2:  # Don't sleep on the last retry
                    time.sleep(1 * (2 ** retry))  # Exponential backoff
                db.close()
                raise
            finally:
                db.close()
        except Exception as e:
            if retry == 2:  # Last retry failed
                print(f"Database connection failed after 3 attempts: {e}")
                raise

def create_user(username, email):
    """Create a new user"""
    def operation():
        db = SessionLocal()
        try:
            user = User(username=username, email=email)
            db.add(user)
            db.commit()
            db.refresh(user)
            return user
        except Exception as e:
            db.rollback()
            raise e
        finally:
            db.close()
    
    return retry_operation(operation)

def get_user_by_username(username):
    """Get a user by username"""
    def operation():
        db = SessionLocal()
        try:
            return db.query(User).filter(User.username == username).first()
        finally:
            db.close()
    
    return retry_operation(operation)

def create_practice_session(user_id, piece_name="Twinkle Twinkle Little Star"):
    """Create a new practice session"""
    def operation():
        db = SessionLocal()
        try:
            session = PracticeSession(user_id=user_id, piece_name=piece_name)
            db.add(session)
            db.commit()
            db.refresh(session)
            return session
        except Exception as e:
            db.rollback()
            raise e
        finally:
            db.close()
    
    return retry_operation(operation)

def end_practice_session(session_id, posture_score=None, bow_score=None, 
                         rhythm_score=None, overall_score=None, notes=None):
    """End a practice session and record scores"""
    def operation():
        db = SessionLocal()
        try:
            session = db.query(PracticeSession).filter(PracticeSession.id == session_id).first()
            if session:
                session.end_time = datetime.datetime.utcnow()
                if session.start_time:
                    session.duration_seconds = (session.end_time - session.start_time).seconds
                
                if posture_score is not None:
                    session.posture_score = posture_score
                if bow_score is not None:
                    session.bow_direction_accuracy = bow_score
                if rhythm_score is not None:
                    session.rhythm_score = rhythm_score
                if overall_score is not None:
                    session.overall_score = overall_score
                if notes is not None:
                    session.notes = notes
                    
                db.commit()
                db.refresh(session)
                return session
            return None
        except Exception as e:
            db.rollback()
            raise e
        finally:
            db.close()
    
    return retry_operation(operation)

def record_practice_event(session_id, event_type, event_data):
    """Record a practice event"""
    def operation():
        db = SessionLocal()
        try:
            event = PracticeEvent(
                session_id=session_id,
                event_type=event_type,
                event_data=event_data
            )
            db.add(event)
            db.commit()
            db.refresh(event)
            return event
        except Exception as e:
            db.rollback()
            raise e
        finally:
            db.close()
    
    return retry_operation(operation)

def save_calibration_profile(user_id, calibration_data, name="Default Profile"):
    """Save a calibration profile"""
    def operation():
        db = SessionLocal()
        try:
            # Deactivate existing profiles
            existing_profiles = db.query(CalibrationProfile).filter(
                CalibrationProfile.user_id == user_id,
                CalibrationProfile.is_active == True
            ).all()
            
            for profile in existing_profiles:
                profile.is_active = False
            
            # Create new profile
            profile = CalibrationProfile(
                user_id=user_id,
                name=name,
                calibration_data=calibration_data,
                is_active=True
            )
            
            db.add(profile)
            db.commit()
            db.refresh(profile)
            return profile
        except Exception as e:
            db.rollback()
            raise e
        finally:
            db.close()
    
    return retry_operation(operation)

def get_active_calibration_profile(user_id):
    """Get the active calibration profile for a user"""
    def operation():
        db = SessionLocal()
        try:
            return db.query(CalibrationProfile).filter(
                CalibrationProfile.user_id == user_id,
                CalibrationProfile.is_active == True
            ).first()
        finally:
            db.close()
    
    return retry_operation(operation)

def get_user_practice_history(user_id, limit=10):
    """Get practice history for a user with connection retry"""
    def operation():
        db = SessionLocal()
        try:
            return db.query(PracticeSession).filter(
                PracticeSession.user_id == user_id
            ).order_by(PracticeSession.start_time.desc()).limit(limit).all()
        finally:
            db.close()
    
    return retry_operation(operation)