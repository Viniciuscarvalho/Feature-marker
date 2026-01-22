import {Composition} from 'remotion';
import {MainVideo} from './compositions/MainVideo';

export const RemotionRoot: React.FC = () => {
	return (
		<>
			<Composition
				id="FeatureMarkerExplainer"
				component={MainVideo}
				durationInFrames={1200}
				fps={30}
				width={1920}
				height={1080}
				defaultProps={{}}
			/>
		</>
	);
};
