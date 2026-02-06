import {Composition, Folder} from 'remotion';
import {MainVideo} from './compositions/MainVideo';
import {V2Explainer} from './compositions/V2Explainer';

export const RemotionRoot: React.FC = () => {
	return (
		<>
			<Folder name="v2.0">
				<Composition
					id="FeatureMarkerV2"
					component={V2Explainer}
					durationInFrames={900}
					fps={30}
					width={1920}
					height={1080}
					defaultProps={{}}
				/>
			</Folder>
			<Folder name="Legacy">
				<Composition
					id="FeatureMarkerExplainer"
					component={MainVideo}
					durationInFrames={1200}
					fps={30}
					width={1920}
					height={1080}
					defaultProps={{}}
				/>
			</Folder>
		</>
	);
};
